import XCTest
import ApplicationServices
@testable import Zcreen

final class OrchestratorTests: XCTestCase {

    func testMenuStatePersistsSettingChanges() {
        let defaults = temporaryUserDefaults()
        let menuState = MenuState(settingsStore: MenuSettingsStore(defaults: defaults))
        menuState.autoApplyOnScreenChange = false
        menuState.autoApplyOnAppLaunch = false
        menuState.snapBarEnabled = false

        XCTAssertFalse(menuState.autoApplyOnScreenChange)
        XCTAssertFalse(menuState.autoApplyOnAppLaunch)
        XCTAssertFalse(menuState.snapBarEnabled)
        XCTAssertEqual(defaults.object(forKey: MenuSettingsStore.Key.autoApplyOnScreenChange.rawValue) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: MenuSettingsStore.Key.autoApplyOnAppLaunch.rawValue) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: MenuSettingsStore.Key.snapBarEnabled.rawValue) as? Bool, false)
    }

    func testScreenSessionTracksPreviousProfileAcrossChanges() {
        let oldScreen = makeScreen(displayID: 1, name: "Built-in Retina Display")
        let newScreen = makeScreen(displayID: 2, name: "Dell U2723QE")
        let detector = makeScreenDetector(screen: oldScreen, profileKey: "old-profile", profileLabel: "Old")
        let session = ScreenSessionService(screenDetector: detector)

        detector.setStateForTesting(screens: [newScreen], profileKey: "new-profile", profileLabel: "New")
        let context = session.beginScreenChange(to: "new-profile")

        XCTAssertEqual(context.oldProfileKey, "old-profile")
        XCTAssertEqual(context.newProfileKey, "new-profile")
        XCTAssertEqual(context.newProfileLabel, "New")
        XCTAssertEqual(session.previousProfileKey, "new-profile")
    }

    func testOrchestratorLoadsPersistedMenuSettings() {
        let defaults = temporaryUserDefaults()
        defaults.set(false, forKey: MenuSettingsStore.Key.autoApplyOnScreenChange.rawValue)
        defaults.set(false, forKey: MenuSettingsStore.Key.autoApplyOnAppLaunch.rawValue)
        defaults.set(false, forKey: MenuSettingsStore.Key.snapBarEnabled.rawValue)

        let orchestrator = makeOrchestrator(
            screenDetector: makeScreenDetector(screen: makeScreen(), profileKey: "main-profile", profileLabel: "Main"),
            configManager: ConfigManager(loadFromDisk: false, configDirectory: tempDirectory()),
            snapshotStore: TestSnapshotStore(),
            settingsStore: MenuSettingsStore(defaults: defaults)
        )

        XCTAssertFalse(orchestrator.autoApplyOnScreenChange)
        XCTAssertFalse(orchestrator.autoApplyOnAppLaunch)
        XCTAssertFalse(orchestrator.snapBarController.isEnabled)
    }

    func testOrchestratorPersistsMenuSettingChanges() {
        let defaults = temporaryUserDefaults()
        let orchestrator = makeOrchestrator(
            screenDetector: makeScreenDetector(screen: makeScreen(), profileKey: "main-profile", profileLabel: "Main"),
            configManager: ConfigManager(loadFromDisk: false, configDirectory: tempDirectory()),
            snapshotStore: TestSnapshotStore(),
            settingsStore: MenuSettingsStore(defaults: defaults)
        )

        orchestrator.autoApplyOnScreenChange = false
        orchestrator.autoApplyOnAppLaunch = false
        orchestrator.snapBarController.isEnabled = false

        XCTAssertEqual(defaults.object(forKey: MenuSettingsStore.Key.autoApplyOnScreenChange.rawValue) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: MenuSettingsStore.Key.autoApplyOnAppLaunch.rawValue) as? Bool, false)
        XCTAssertEqual(defaults.object(forKey: MenuSettingsStore.Key.snapBarEnabled.rawValue) as? Bool, false)
    }

    func testManualSaveDoesNotOverwriteExistingSnapshotWithEmptyCapture() {
        let screen = makeScreen()
        let detector = makeScreenDetector(screen: screen, profileKey: "main-profile", profileLabel: "Main")
        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let snapshotStore = TestSnapshotStore()
        let existingSnapshot = makeLayoutSnapshot(profileKey: "main-profile", profileLabel: "Main", titles: ["Existing"])
        snapshotStore.storedSnapshots["main-profile"] = existingSnapshot
        snapshotStore.nextCapturedSnapshot = makeLayoutSnapshot(profileKey: "main-profile", profileLabel: "Main", titles: [])

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            snapshotStore: snapshotStore
        )

        orchestrator.saveCurrentLayout()

        XCTAssertEqual(snapshotStore.saveCallCount, 0)
        XCTAssertEqual(orchestrator.lastAction, "No windows available to save")
        XCTAssertEqual(snapshotStore.load(profileKey: "main-profile")?.windows.count, 1)
    }

    func testPeriodicAutoSaveSkipsUnchangedLayout() {
        let screen = makeScreen()
        let detector = makeScreenDetector(screen: screen, profileKey: "main-profile", profileLabel: "Main")
        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let snapshotStore = TestSnapshotStore()
        let unchanged = makeLayoutSnapshot(profileKey: "main-profile", profileLabel: "Main", titles: ["Editor"])
        snapshotStore.storedSnapshots["main-profile"] = unchanged
        snapshotStore.nextCapturedSnapshot = unchanged

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            snapshotStore: snapshotStore
        )

        orchestrator.performPeriodicAutoSaveForTesting()

        XCTAssertEqual(snapshotStore.saveCallCount, 0)
    }

    func testScreenChangeSchedulesDelayedAutoSave() {
        let oldScreen = makeScreen(displayID: 1, name: "Built-in Retina Display", frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        let newScreen = makeScreen(displayID: 2, name: "Dell U2723QE", frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440))
        let detector = makeScreenDetector(screen: oldScreen, profileKey: "old-profile", profileLabel: "Old")
        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let snapshotStore = TestSnapshotStore()
        let scheduler = TestScheduler()

        snapshotStore.storedSnapshots["new-profile"] = makeLayoutSnapshot(
            profileKey: "new-profile",
            profileLabel: "New",
            titles: ["Restored"]
        )
        snapshotStore.nextCapturedSnapshot = makeLayoutSnapshot(
            profileKey: "new-profile",
            profileLabel: "New",
            titles: ["Saved Again"]
        )

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            snapshotStore: snapshotStore,
            scheduler: scheduler
        )

        detector.setStateForTesting(screens: [newScreen], profileKey: "new-profile", profileLabel: "New")
        orchestrator.handleScreenChange(newProfileKey: "new-profile")

        XCTAssertEqual(snapshotStore.restoreCallCount, 1)
        XCTAssertEqual(scheduler.delays, [Constants.Timing.screenChangeAutoSaveDelay])

        scheduler.runAll()

        XCTAssertEqual(snapshotStore.saveCallCount, 1)
    }

    func testAppLaunchSchedulesDelayedAutoSaveAfterRuleMatch() {
        let screen = makeScreen(name: "Built-in Retina Display", frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        let detector = makeScreenDetector(screen: screen, profileKey: "main-profile", profileLabel: "Main")
        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let scheduler = TestScheduler()
        let snapshotStore = TestSnapshotStore()
        let windowManager = TestWindowManager()
        let config = Configuration(
            version: 1,
            debounceMs: 500,
            screens: [ScreenAlias(alias: "main", nameContains: "Built-in")],
            rules: [Rule(app: AppMatcher(bundleId: "com.test.app", nameContains: nil), targetScreen: "main", profileOverrides: nil)],
            profiles: nil,
            windowFilter: nil
        )
        configManager.setStateForTesting(configuration: config)
        windowManager.windowsByBundle["com.test.app"] = [
            makeWindowInfo(bundleId: "com.test.app", title: "Editor", frame: CGRect(x: 40, y: 40, width: 600, height: 400))
        ]
        snapshotStore.nextCapturedSnapshot = makeLayoutSnapshot(
            profileKey: "main-profile",
            profileLabel: "Main",
            titles: ["Editor"]
        )

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            windowManager: windowManager,
            snapshotStore: snapshotStore,
            scheduler: scheduler
        )

        orchestrator.handleAppLaunch(bundleId: "com.test.app", appName: "Test App")

        XCTAssertEqual(scheduler.delays, [Constants.Timing.appLaunchAutoSaveDelay])
        XCTAssertEqual(orchestrator.lastAction, "Moved Test App to main")

        scheduler.runAll()

        XCTAssertEqual(snapshotStore.saveCallCount, 1)
    }

    func testManualRestoreReportsMissingSnapshot() {
        let screen = makeScreen()
        let detector = makeScreenDetector(screen: screen, profileKey: "main-profile", profileLabel: "Main")
        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let snapshotStore = TestSnapshotStore()

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            snapshotStore: snapshotStore
        )

        orchestrator.restoreCurrentLayout()

        XCTAssertEqual(orchestrator.lastAction, "No saved layout for Main")
        XCTAssertEqual(snapshotStore.restoreCallCount, 0)
    }

    func testApplyAllRulesSupportsNameContainsMatcher() {
        let screen = makeScreen()
        let detector = makeScreenDetector(screen: screen, profileKey: "main-profile", profileLabel: "Main")
        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let snapshotStore = TestSnapshotStore()
        let windowManager = TestWindowManager()
        let config = Configuration(
            version: 1,
            debounceMs: 500,
            screens: [ScreenAlias(alias: "main", nameContains: "Built-in")],
            rules: [Rule(app: AppMatcher(bundleId: nil, nameContains: "Slack"), targetScreen: "main", profileOverrides: nil)],
            profiles: nil,
            windowFilter: nil
        )
        configManager.setStateForTesting(configuration: config)
        windowManager.windowsByBundle["com.tinyspeck.slackmacgap"] = [
            makeWindowInfo(
                bundleId: "com.tinyspeck.slackmacgap",
                title: "Workspace",
                frame: CGRect(x: 2200, y: 100, width: 900, height: 700),
                appName: "Slack"
            )
        ]

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            windowManager: windowManager,
            snapshotStore: snapshotStore
        )

        orchestrator.applyAllRules()

        XCTAssertEqual(windowManager.moveToScreenCallCount, 1)
        XCTAssertEqual(orchestrator.lastAction, "Applied 1 rule moves")
    }

    func testApplyAllRulesSkipsWindowAlreadyOnTargetExternalDisplay() {
        let mainScreen = makeScreen(
            displayID: 1,
            name: "Built-in Retina Display",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
        )
        let externalScreen = makeScreen(
            displayID: 2,
            name: "Dell U2723QE",
            frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        )
        let detector = ScreenDetector(shouldRegisterCallback: false)
        detector.setStateForTesting(screens: [mainScreen, externalScreen], profileKey: "dual", profileLabel: "Dual")

        let configManager = ConfigManager(loadFromDisk: false, configDirectory: tempDirectory())
        let snapshotStore = TestSnapshotStore()
        let windowManager = TestWindowManager()
        let config = Configuration(
            version: 1,
            debounceMs: 500,
            screens: [ScreenAlias(alias: "external", nameContains: "Dell")],
            rules: [Rule(app: AppMatcher(bundleId: nil, nameContains: "Slack"), targetScreen: "external", profileOverrides: nil)],
            profiles: nil,
            windowFilter: nil
        )
        configManager.setStateForTesting(configuration: config)
        windowManager.windowsByBundle["com.tinyspeck.slackmacgap"] = [
            makeWindowInfo(
                bundleId: "com.tinyspeck.slackmacgap",
                title: "Workspace",
                frame: CGRect(x: 1800, y: -120, width: 900, height: 700),
                appName: "Slack"
            )
        ]

        let orchestrator = makeOrchestrator(
            screenDetector: detector,
            configManager: configManager,
            windowManager: windowManager,
            snapshotStore: snapshotStore
        )

        orchestrator.applyAllRules()

        XCTAssertEqual(windowManager.moveToScreenCallCount, 0)
        XCTAssertEqual(orchestrator.lastAction, "Applied 0 rule moves")
    }

    private func makeOrchestrator(
        screenDetector: ScreenDetector,
        configManager: ConfigManager,
        windowManager: WindowManager = TestWindowManager(),
        snapshotStore: LayoutSnapshotStore,
        scheduler: TestScheduler? = nil,
        settingsStore: MenuSettingsStore? = nil
    ) -> Orchestrator {
        let runLoopScheduler = scheduler ?? TestScheduler()
        let resolvedSettingsStore = settingsStore ?? MenuSettingsStore(defaults: temporaryUserDefaults())
        return Orchestrator(
            screenDetector: screenDetector,
            configManager: configManager,
            windowManager: windowManager,
            snapshotStore: snapshotStore,
            snapBarController: SnapBarController(windowManager: windowManager, shouldStartPolling: false),
            autoUpdater: AutoUpdater(autoCheckOnLaunch: false),
            settingsStore: resolvedSettingsStore,
            isAccessibilityTrusted: { true },
            requestAccessibilityAccess: {},
            scheduleAfter: { delay, action in
                runLoopScheduler.schedule(after: delay, action)
            },
            enableAppLaunchObserver: false,
            enableAutoSaveTimer: false
        )
    }

    private func makeScreenDetector(screen: ScreenInfo, profileKey: String, profileLabel: String) -> ScreenDetector {
        let detector = ScreenDetector(shouldRegisterCallback: false)
        detector.setStateForTesting(screens: [screen], profileKey: profileKey, profileLabel: profileLabel)
        return detector
    }

    private func makeLayoutSnapshot(profileKey: String, profileLabel: String, titles: [String]) -> LayoutSnapshot {
        LayoutSnapshot(
            profileKey: profileKey,
            profileLabel: profileLabel,
            timestamp: Date(),
            windows: titles.map {
                WindowSnapshot(
                    bundleId: "com.test.app",
                    appName: "Test App",
                    windowTitle: $0,
                    frame: .init(CGRect(x: 20, y: 30, width: 600, height: 400)),
                    screenName: profileLabel,
                    screenKey: "screen-key-\(profileLabel)",
                    relativeFrame: .init(x: 0.1, y: 0.1, width: 0.5, height: 0.5),
                    windowRole: "AXWindow",
                    windowSubrole: "AXStandardWindow"
                )
            }
        )
    }

    private func makeScreen(displayID: CGDirectDisplayID = 1, name: String = "Built-in Retina Display",
                            frame: CGRect = CGRect(x: 0, y: 0, width: 1512, height: 982)) -> ScreenInfo {
        ScreenInfo(
            displayID: displayID,
            name: name,
            frame: frame,
            isBuiltIn: true,
            position: .single,
            vendorID: UInt32(displayID),
            modelID: 100 + UInt32(displayID),
            serialNumber: 1000 + UInt32(displayID)
        )
    }

    private func makeWindowInfo(bundleId: String, title: String?, frame: CGRect, appName: String = "Test App") -> WindowManager.WindowInfo {
        WindowManager.WindowInfo(
            pid: 1,
            bundleId: bundleId,
            appName: appName,
            title: title,
            role: "AXWindow",
            subrole: "AXStandardWindow",
            isMinimized: false,
            frame: frame,
            axWindow: AXUIElementCreateSystemWide()
        )
    }

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func temporaryUserDefaults() -> UserDefaults {
        let suiteName = "zcreen.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class TestScheduler {
    private(set) var delays: [TimeInterval] = []
    private var actions: [() -> Void] = []

    func schedule(after delay: TimeInterval, _ action: @escaping () -> Void) {
        delays.append(delay)
        actions.append(action)
    }

    func runAll() {
        let pending = actions
        actions.removeAll()
        pending.forEach { $0() }
    }
}

private final class TestSnapshotStore: LayoutSnapshotStore {
    var nextCapturedSnapshot = LayoutSnapshot(profileKey: "", profileLabel: "", timestamp: Date(), windows: [])
    var storedSnapshots: [String: LayoutSnapshot] = [:]
    private(set) var saveCallCount = 0
    private(set) var restoreCallCount = 0

    init() {
        super.init(snapshotDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), loadExisting: false)
    }

    override func save(snapshot: LayoutSnapshot) {
        saveCallCount += 1
        storedSnapshots[snapshot.profileKey] = snapshot
    }

    override func load(profileKey: String) -> LayoutSnapshot? {
        storedSnapshots[profileKey]
    }

    override func captureSnapshot(profileKey: String, profileLabel: String, windowManager: WindowManager,
                                  screens: [ScreenInfo], windowFilter: WindowFilter) -> LayoutSnapshot {
        nextCapturedSnapshot
    }

    override func restoreSnapshot(_ snapshot: LayoutSnapshot, windowManager: WindowManager,
                                  excludeBundleIds: Set<String>, windowFilter: WindowFilter) {
        restoreCallCount += 1
    }
}

private final class TestWindowManager: WindowManager {
    var windowsByBundle: [String: [WindowInfo]] = [:]
    private(set) var moveToScreenCallCount = 0

    override func getAllWindows() -> [WindowInfo] {
        windowsByBundle.values.flatMap { $0 }
    }

    override func getWindows(bundleId: String) -> [WindowInfo] {
        windowsByBundle[bundleId] ?? []
    }

    override func moveWindowToScreen(_ window: AXUIElement, currentFrame: CGRect, targetScreen: ScreenInfo) {
        moveToScreenCallCount += 1
    }
}
