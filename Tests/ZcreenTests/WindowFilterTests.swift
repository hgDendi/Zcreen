import XCTest
import ApplicationServices
@testable import Zcreen

final class WindowFilterTests: XCTestCase {

    func testDefaultFilterExcludesFloatingAndMinimizedWindows() {
        let filter = WindowFilter(configuration: .empty)

        XCTAssertFalse(filter.allows(window: makeWindow(subrole: "AXFloatingWindow")))
        XCTAssertFalse(filter.allows(window: makeWindow(isMinimized: true)))
        XCTAssertTrue(filter.allows(window: makeWindow()))
    }

    func testConfigurationFilterExcludesAppsByMatcher() {
        let config = Configuration(
            version: 1,
            debounceMs: 500,
            screens: nil,
            rules: nil,
            profiles: nil,
            windowFilter: WindowFilterConfig(
                excludedApps: [AppMatcher(bundleId: nil, nameContains: "Finder")],
                excludedRoles: nil,
                excludedSubroles: nil,
                minWidth: nil,
                minHeight: nil,
                excludeMinimized: true
            )
        )
        let filter = WindowFilter(configuration: config)

        XCTAssertFalse(filter.allows(window: makeWindow(bundleId: "com.apple.finder", appName: "Finder")))
        XCTAssertTrue(filter.allows(window: makeWindow(bundleId: "com.google.Chrome", appName: "Google Chrome")))
    }

    private func makeWindow(bundleId: String? = "com.test.app", appName: String = "Test App",
                            role: String? = "AXWindow", subrole: String? = "AXStandardWindow",
                            frame: CGRect = CGRect(x: 0, y: 0, width: 1200, height: 800),
                            isMinimized: Bool = false) -> WindowManager.WindowInfo {
        WindowManager.WindowInfo(
            pid: 1,
            bundleId: bundleId,
            appName: appName,
            title: "Editor",
            role: role,
            subrole: subrole,
            isMinimized: isMinimized,
            frame: frame,
            axWindow: AXUIElementCreateSystemWide()
        )
    }
}
