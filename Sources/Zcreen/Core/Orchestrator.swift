import Cocoa
import Combine

final class Orchestrator: ObservableObject {
    @Published private(set) var lastAction: String = ""

    let screenDetector: ScreenDetector
    let configManager: ConfigManager
    let windowManager: WindowManager
    let snapshotStore: LayoutSnapshotStore
    let ruleEngine: RuleEngine
    let snapBarController: SnapBarController
    let caffeinateManager: CaffeinateManager
    let autoUpdater: AutoUpdater
    let menuState: MenuState

    private let screenSessionService: ScreenSessionService
    private let snapshotService: SnapshotService
    private let ruleApplyService: RuleApplyService
    private let isAccessibilityTrusted: () -> Bool
    private let requestAccessibilityAccess: () -> Void
    private let scheduleAfter: (TimeInterval, @escaping () -> Void) -> Void

    private var cancellables = Set<AnyCancellable>()
    private var autoSaveTimer: Timer?

    var autoApplyOnScreenChange: Bool {
        get { menuState.autoApplyOnScreenChange }
        set { menuState.autoApplyOnScreenChange = newValue }
    }

    var autoApplyOnAppLaunch: Bool {
        get { menuState.autoApplyOnAppLaunch }
        set { menuState.autoApplyOnAppLaunch = newValue }
    }

    init(
        screenDetector: ScreenDetector = ScreenDetector(),
        configManager: ConfigManager = ConfigManager(),
        windowManager: WindowManager = WindowManager(),
        snapshotStore: LayoutSnapshotStore = LayoutSnapshotStore(),
        ruleEngine: RuleEngine = RuleEngine(),
        snapBarController: SnapBarController? = nil,
        caffeinateManager: CaffeinateManager = CaffeinateManager(),
        autoUpdater: AutoUpdater = AutoUpdater(),
        settingsStore: MenuSettingsStore = MenuSettingsStore(),
        isAccessibilityTrusted: @escaping () -> Bool = { AccessibilityHelper.isTrusted },
        requestAccessibilityAccess: @escaping () -> Void = { AccessibilityHelper.requestAccess() },
        scheduleAfter: @escaping (TimeInterval, @escaping () -> Void) -> Void = { delay, action in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
        },
        enableAppLaunchObserver: Bool = true,
        enableAutoSaveTimer: Bool = true
    ) {
        self.screenDetector = screenDetector
        self.configManager = configManager
        self.windowManager = windowManager
        self.snapshotStore = snapshotStore
        self.ruleEngine = ruleEngine

        let resolvedSnapBarController = snapBarController ?? SnapBarController(windowManager: windowManager)
        self.snapBarController = resolvedSnapBarController
        self.caffeinateManager = caffeinateManager
        self.autoUpdater = autoUpdater

        let resolvedMenuState = MenuState(settingsStore: settingsStore)
        resolvedMenuState.connect(snapBarController: resolvedSnapBarController)
        self.menuState = resolvedMenuState

        let resolvedScreenSessionService = ScreenSessionService(screenDetector: screenDetector)
        self.screenSessionService = resolvedScreenSessionService
        self.snapshotService = SnapshotService(
            screenSession: resolvedScreenSessionService,
            configManager: configManager,
            windowManager: windowManager,
            snapshotStore: snapshotStore
        )
        self.ruleApplyService = RuleApplyService(
            screenSession: resolvedScreenSessionService,
            configManager: configManager,
            windowManager: windowManager,
            ruleEngine: ruleEngine,
            scheduleAfter: scheduleAfter
        )

        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.requestAccessibilityAccess = requestAccessibilityAccess
        self.scheduleAfter = scheduleAfter

        resolvedSnapBarController.onSnap = { [weak self] in
            self?.autoSaveCurrentLayout(trigger: .snapBar)
        }

        forwardChanges(from: snapshotStore)
        forwardChanges(from: screenDetector)
        forwardChanges(from: autoUpdater)
        forwardChanges(from: configManager)
        forwardChanges(from: resolvedSnapBarController)
        forwardChanges(from: resolvedMenuState)

        setupScreenChangeHandler()
        if enableAppLaunchObserver {
            setupAppLaunchHandler()
        }
        if enableAutoSaveTimer {
            setupAutoSaveTimer()
        }
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Public actions

    func applyAllRules() {
        guard ensureAccessibilityPermission(promptIfNeeded: true) else { return }

        let result = ruleApplyService.applyAllRules()
        lastAction = result.statusMessage
        Log.rule.info("\(self.lastAction, privacy: .public)")
    }

    func saveCurrentLayout() {
        guard ensureAccessibilityPermission(promptIfNeeded: true) else { return }

        let result = snapshotService.saveCurrentLayout(trigger: .manual, force: true)
        if let statusMessage = result.statusMessage {
            lastAction = statusMessage
        }
    }

    func restoreCurrentLayout() {
        guard ensureAccessibilityPermission(promptIfNeeded: true) else { return }

        lastAction = snapshotService.restoreCurrentLayout().statusMessage
    }

    // MARK: - Post-change restore

    private func setupScreenChangeHandler() {
        screenDetector.onScreensChanged
            .sink { [weak self] newProfileKey in
                guard let self, self.menuState.autoApplyOnScreenChange else { return }
                self.handleScreenChange(newProfileKey: newProfileKey)
            }
            .store(in: &cancellables)
    }

    func handleScreenChange(newProfileKey: String) {
        guard ensureAccessibilityPermission(promptIfNeeded: false) else { return }

        let context = screenSessionService.beginScreenChange(to: newProfileKey)
        Log.general.info("Screen change: '\(context.oldProfileKey)' -> '\(context.newProfileKey)' (\(context.newProfileLabel))")

        let restoreResult = snapshotService.restoreLayout(
            profileKey: context.newProfileKey,
            profileLabel: context.newProfileLabel
        )
        switch restoreResult {
        case .restored:
            lastAction = restoreResult.statusMessage
        case .missing:
            _ = ruleApplyService.applyFallbackRulesIfAvailable()
            lastAction = "New screen combo: \(context.newProfileLabel)"
            Log.snapshot.info("No snapshot for '\(context.newProfileLabel)', used rules as fallback")
        }

        scheduleDelayedAutoSave(trigger: .screenChange, delay: Constants.Timing.screenChangeAutoSaveDelay)
    }

    // MARK: - App launch rules

    private func setupAppLaunchHandler() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .sink { [weak self] app in
                guard let self, self.menuState.autoApplyOnAppLaunch else { return }
                self.handleAppLaunch(bundleId: app.bundleIdentifier, appName: app.localizedName)
            }
            .store(in: &cancellables)
    }

    func handleAppLaunch(bundleId: String?, appName: String?) {
        guard ensureAccessibilityPermission(promptIfNeeded: false) else { return }

        ruleApplyService.handleAppLaunch(bundleId: bundleId, appName: appName) { [weak self] result in
            guard let self, let result else { return }

            self.lastAction = result.statusMessage
            self.scheduleDelayedAutoSave(trigger: .appLaunch, delay: Constants.Timing.appLaunchAutoSaveDelay)
        }
    }

    private func setupAutoSaveTimer() {
        let timer = Timer(timeInterval: Constants.Timing.layoutAutoSaveInterval, repeats: true) { [weak self] _ in
            self?.autoSaveCurrentLayout(trigger: .periodic)
        }
        RunLoop.main.add(timer, forMode: .common)
        autoSaveTimer = timer
    }

    private func scheduleDelayedAutoSave(trigger: SnapshotService.Trigger, delay: TimeInterval) {
        scheduleAfter(delay) { [weak self] in
            self?.autoSaveCurrentLayout(trigger: trigger)
        }
    }

    func performPeriodicAutoSaveForTesting() {
        autoSaveCurrentLayout(trigger: .periodic)
    }

    private func autoSaveCurrentLayout(trigger: SnapshotService.Trigger) {
        guard ensureAccessibilityPermission(promptIfNeeded: false) else { return }
        _ = snapshotService.saveCurrentLayout(trigger: trigger, force: false)
    }

    @discardableResult
    private func ensureAccessibilityPermission(promptIfNeeded: Bool) -> Bool {
        guard isAccessibilityTrusted() else {
            if promptIfNeeded {
                lastAction = "Accessibility permission required"
                requestAccessibilityAccess()
            }
            return false
        }

        return true
    }

    private func forwardChanges<Object: ObservableObject>(from object: Object) {
        object.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
