import XCTest
@testable import Zcreen

final class WindowMatcherTests: XCTestCase {

    func testMatchesWindowsByExactTitleEvenWhenOrderDiffers() {
        let saved = [
            makeSnapshot(title: "Inbox", width: 900, height: 700),
            makeSnapshot(title: "Calendar", width: 800, height: 600),
        ]
        let running = [
            makeCandidate(title: "Calendar", width: 800, height: 600),
            makeCandidate(title: "Inbox", width: 900, height: 700),
        ]

        let assignments = WindowMatcher.match(saved: saved, running: running)

        XCTAssertEqual(assignments.count, 2)
        XCTAssertEqual(assignments.first(where: { $0.savedIndex == 0 })?.runningIndex, 1)
        XCTAssertEqual(assignments.first(where: { $0.savedIndex == 1 })?.runningIndex, 0)
    }

    func testFallsBackToRoleAndSizeForUntitledWindows() {
        let saved = [
            makeSnapshot(title: nil, width: 1200, height: 900, role: "AXWindow", subrole: "AXStandardWindow"),
            makeSnapshot(title: nil, width: 700, height: 500, role: "AXWindow", subrole: "AXStandardWindow"),
        ]
        let running = [
            makeCandidate(title: nil, width: 700, height: 500, role: "AXWindow", subrole: "AXStandardWindow"),
            makeCandidate(title: nil, width: 1200, height: 900, role: "AXWindow", subrole: "AXStandardWindow"),
        ]

        let assignments = WindowMatcher.match(saved: saved, running: running)

        XCTAssertEqual(assignments.count, 2)
        XCTAssertEqual(assignments.first(where: { $0.savedIndex == 0 })?.runningIndex, 1)
        XCTAssertEqual(assignments.first(where: { $0.savedIndex == 1 })?.runningIndex, 0)
    }

    func testLowConfidenceWhenOnlyWeakSignalsExist() {
        let saved = [
            makeSnapshot(title: nil, width: 800, height: 600, role: nil, subrole: nil, screenName: "Unknown"),
        ]
        let running = [
            makeCandidate(title: nil, width: 800, height: 600, role: nil, subrole: nil, screenName: "Unknown"),
        ]

        let assignments = WindowMatcher.match(saved: saved, running: running)

        XCTAssertEqual(assignments.count, 1)
        XCTAssertTrue(assignments[0].isLowConfidence)
    }

    private func makeSnapshot(title: String?, width: Double, height: Double,
                              role: String? = "AXWindow", subrole: String? = "AXStandardWindow",
                              screenName: String = "Main") -> WindowSnapshot {
        WindowSnapshot(
            bundleId: "com.test.app",
            appName: "Test App",
            windowTitle: title,
            frame: .init(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))),
            screenName: screenName,
            windowRole: role,
            windowSubrole: subrole
        )
    }

    private func makeCandidate(title: String?, width: CGFloat, height: CGFloat,
                               role: String? = "AXWindow", subrole: String? = "AXStandardWindow",
                               screenName: String = "Main") -> WindowMatchCandidate {
        WindowMatchCandidate(
            title: title,
            frame: CGRect(x: 0, y: 0, width: width, height: height),
            screenName: screenName,
            role: role,
            subrole: subrole
        )
    }
}
