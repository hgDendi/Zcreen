import Cocoa
import Combine

final class Orchestrator: ObservableObject {
    @Published var autoApplyOnScreenChange = true
    @Published var autoApplyOnAppLaunch = true
    @Published private(set) var lastAction: String = ""

    let screenDetector: ScreenDetector
    let configManager: ConfigManager
    let windowManager: WindowManager
    let snapshotStore: LayoutSnapshotStore
    let ruleEngine: RuleEngine
    var snapBarController: SnapBarController
    let caffeinateManager: CaffeinateManager

    private var cancellables = Set<AnyCancellable>()
    private var previousProfileKey: String = ""
    private var hasSavedPreChangeSnapshot = false

    init() {
        screenDetector = ScreenDetector()
        configManager = ConfigManager()
        windowManager = WindowManager()
        snapshotStore = LayoutSnapshotStore()
        ruleEngine = RuleEngine()
        snapBarController = SnapBarController(windowManager: windowManager)
        caffeinateManager = CaffeinateManager()

        snapBarController.onSnap = { [weak self] in
            self?.autoSaveCurrentLayout()
        }

        previousProfileKey = screenDetector.profileKey

        setupBeginConfigHandler()
        setupScreenChangeHandler()
        setupAppLaunchHandler()
        // Snapshots are only saved via Snap Bar (onSnap callback)
    }

    // MARK: - Public actions

    func applyAllRules() {
        guard AccessibilityHelper.isTrusted else {
            lastAction = "Accessibility permission required"
            AccessibilityHelper.requestAccess()
            return
        }

        let config = configManager.configuration
        guard !config.effectiveRules.isEmpty else {
            lastAction = "No rules configured"
            return
        }

        let matches = ruleEngine.matchRules(configuration: config, screenCount: screenDetector.screenCount)
        var applied = 0

        for match in matches {
            guard let targetScreen = screenDetector.screenInfo(forAlias: match.targetScreenAlias, configuration: config)
            else { continue }

            let windows = windowManager.getWindows(bundleId: match.bundleId)
            for win in windows {
                if targetScreen.frame.contains(CGPoint(x: win.frame.midX, y: win.frame.midY)) { continue }
                windowManager.moveWindowToScreen(win.axWindow, currentFrame: win.frame, targetScreen: targetScreen)
                applied += 1
            }
        }

        lastAction = "Applied \(applied) rule moves"
        Log.rule.info("\(self.lastAction)")
    }

    func saveCurrentLayout() {
        guard AccessibilityHelper.isTrusted else {
            lastAction = "Accessibility permission required"
            AccessibilityHelper.requestAccess()
            return
        }

        let snapshot = snapshotStore.captureSnapshot(
            profileKey: screenDetector.profileKey,
            profileLabel: screenDetector.profileLabel,
            windowManager: windowManager,
            screens: screenDetector.screens
        )
        snapshotStore.save(snapshot: snapshot)
        lastAction = "Saved layout (\(snapshot.windows.count) windows)"
    }

    // MARK: - Pre-change snapshot (beginConfigurationFlag)

    private func setupBeginConfigHandler() {
        // Disabled: beginConfigurationFlag fires AFTER macOS has already moved windows
        // to the remaining screens, so the "pre-change" snapshot contains crammed data
        // and overwrites the good snapshot from Snap Bar / periodic save.
        // We rely on onSnap + periodic auto-save to keep snapshots up to date.
    }

    // MARK: - Post-change restore

    private func setupScreenChangeHandler() {
        screenDetector.onScreensChanged
            .sink { [weak self] newProfileKey in
                guard let self, self.autoApplyOnScreenChange else { return }
                self.handleScreenChange(newProfileKey: newProfileKey)
            }
            .store(in: &cancellables)
    }

    private func handleScreenChange(newProfileKey: String) {
        guard AccessibilityHelper.isTrusted else { return }

        let oldProfileKey = previousProfileKey
        let newLabel = screenDetector.profileLabel
        Log.general.info("Screen change: '\(oldProfileKey)' -> '\(newProfileKey)' (\(newLabel))")

        // Reset pre-change flag
        hasSavedPreChangeSnapshot = false

        // Snapshot-first: restore ALL apps from saved positions
        if let snapshot = snapshotStore.load(profileKey: newProfileKey) {
            snapshotStore.restoreSnapshot(snapshot, windowManager: windowManager, excludeBundleIds: [])
            lastAction = "Restored layout for \(newLabel)"
            Log.snapshot.info("Restored \(snapshot.windows.count) windows for '\(newLabel)'")
        } else {
            // No snapshot — fall back to rules if configured
            let config = configManager.configuration
            if !config.effectiveRules.isEmpty {
                let matches = ruleEngine.matchRules(configuration: config, screenCount: screenDetector.screenCount)
                for match in matches {
                    guard let targetScreen = screenDetector.screenInfo(forAlias: match.targetScreenAlias, configuration: config)
                    else { continue }
                    let windows = windowManager.getWindows(bundleId: match.bundleId)
                    for win in windows {
                        if targetScreen.frame.contains(CGPoint(x: win.frame.midX, y: win.frame.midY)) { continue }
                        windowManager.moveWindowToScreen(win.axWindow, currentFrame: win.frame, targetScreen: targetScreen)
                    }
                }
            }
            lastAction = "New screen combo: \(newLabel)"
            Log.snapshot.info("No snapshot for '\(newLabel)', used rules as fallback")
        }

        previousProfileKey = newProfileKey

        // Don't auto-save immediately after restore — the restored layout is from
        // the snapshot and saving it back would be redundant. Only Snap Bar actions
        // and the periodic timer (every 2 min) should update snapshots.
    }

    // MARK: - App launch rules

    private func setupAppLaunchHandler() {
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .delay(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] app in
                guard let self, self.autoApplyOnAppLaunch else { return }
                self.handleAppLaunch(app)
            }
            .store(in: &cancellables)
    }

    private func handleAppLaunch(_ app: NSRunningApplication) {
        guard AccessibilityHelper.isTrusted else { return }

        let config = configManager.configuration
        guard !config.effectiveRules.isEmpty else { return }

        let bundleId = app.bundleIdentifier
        let appName = app.localizedName

        guard let match = ruleEngine.matchRule(
            for: bundleId, appName: appName,
            configuration: config,
            screenCount: screenDetector.screenCount
        ) else { return }

        guard let targetScreen = screenDetector.screenInfo(forAlias: match.targetScreenAlias, configuration: config)
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let windows = self.windowManager.getWindows(bundleId: match.bundleId)
            for win in windows {
                if targetScreen.frame.contains(CGPoint(x: win.frame.midX, y: win.frame.midY)) { continue }
                self.windowManager.moveWindowToScreen(win.axWindow, currentFrame: win.frame, targetScreen: targetScreen)
            }
            Log.rule.info("Launch rule: \(appName ?? "unknown") -> \(match.targetScreenAlias)")
            self.lastAction = "Moved \(appName ?? "app") to \(match.targetScreenAlias)"
        }
    }

    private func autoSaveCurrentLayout() {
        guard AccessibilityHelper.isTrusted else { return }

        let snapshot = snapshotStore.captureSnapshot(
            profileKey: screenDetector.profileKey,
            profileLabel: screenDetector.profileLabel,
            windowManager: windowManager,
            screens: screenDetector.screens
        )

        guard !snapshot.windows.isEmpty else { return }
        snapshotStore.save(snapshot: snapshot)
    }
}
