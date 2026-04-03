import XCTest
@testable import Zcreen

final class WindowSnapshotTests: XCTestCase {

    func testRelativeFrameRoundTripsWithinScreen() {
        let screenFrame = CGRect(x: 100, y: 200, width: 1600, height: 900)
        let windowFrame = CGRect(x: 300, y: 350, width: 800, height: 450)

        let relative = WindowSnapshot.CodableRect.relative(from: windowFrame, in: screenFrame)
        let restored = relative.cgRect(in: screenFrame)

        XCTAssertEqual(restored.origin.x, windowFrame.origin.x, accuracy: 0.001)
        XCTAssertEqual(restored.origin.y, windowFrame.origin.y, accuracy: 0.001)
        XCTAssertEqual(restored.width, windowFrame.width, accuracy: 0.001)
        XCTAssertEqual(restored.height, windowFrame.height, accuracy: 0.001)
    }

    func testResolvedFramePrefersPhysicalScreenKeyOverAbsoluteFrame() {
        let mainScreen = ScreenInfo(
            displayID: 1,
            name: "Built-in Retina Display",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            isBuiltIn: true,
            position: .leftmost,
            vendorID: 1,
            modelID: 11,
            serialNumber: 111
        )
        let screen = ScreenInfo(
            displayID: 1,
            name: "Dell",
            frame: CGRect(x: 1512, y: 0, width: 1200, height: 982),
            isBuiltIn: false,
            position: .rightmost,
            vendorID: 10,
            modelID: 20,
            serialNumber: 30
        )
        let relative = WindowSnapshot.CodableRect(x: 0.1, y: 0.2, width: 0.5, height: 0.25)
        let snapshot = WindowSnapshot(
            bundleId: "com.test.app",
            appName: "Test",
            windowTitle: "Editor",
            frame: .init(CGRect(x: 0, y: 0, width: 400, height: 300)),
            screenName: "Old Dell",
            screenKey: screen.uniqueKey,
            relativeFrame: relative,
            windowRole: "AXWindow",
            windowSubrole: "AXStandardWindow"
        )

        let resolved = snapshot.resolvedFrame(using: [mainScreen, screen])

        XCTAssertEqual(resolved.origin.x, 1632, accuracy: 0.001)
        XCTAssertEqual(resolved.origin.y, 196.4, accuracy: 0.001)
        XCTAssertEqual(resolved.width, 600, accuracy: 0.001)
        XCTAssertEqual(resolved.height, 245.5, accuracy: 0.001)
    }

    func testResolvedFrameUsesMainScreenReferenceForTallerExternalDisplay() {
        let mainScreen = ScreenInfo(
            displayID: 1,
            name: "Built-in Retina Display",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            isBuiltIn: true,
            position: .leftmost,
            vendorID: 1,
            modelID: 11,
            serialNumber: 111
        )
        let externalScreen = ScreenInfo(
            displayID: 2,
            name: "Dell U2723QE",
            frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440),
            isBuiltIn: false,
            position: .rightmost,
            vendorID: 10,
            modelID: 20,
            serialNumber: 30
        )
        let snapshot = WindowSnapshot(
            bundleId: "com.test.app",
            appName: "Test",
            windowTitle: "Editor",
            frame: .init(CGRect(x: 0, y: 0, width: 400, height: 300)),
            screenName: "Dell U2723QE",
            screenKey: externalScreen.uniqueKey,
            relativeFrame: .init(x: 0.1, y: 0.2, width: 0.5, height: 0.25),
            windowRole: "AXWindow",
            windowSubrole: "AXStandardWindow"
        )

        let resolved = snapshot.resolvedFrame(using: [mainScreen, externalScreen])

        XCTAssertEqual(resolved.origin.x, 1768, accuracy: 0.001)
        XCTAssertEqual(resolved.origin.y, -170, accuracy: 0.001)
        XCTAssertEqual(resolved.width, 1280, accuracy: 0.001)
        XCTAssertEqual(resolved.height, 360, accuracy: 0.001)
    }

    func testResolvedFrameFallsBackToAbsoluteFrameWhenScreenMissing() {
        let snapshot = WindowSnapshot(
            bundleId: "com.test.app",
            appName: "Test",
            windowTitle: "Editor",
            frame: .init(CGRect(x: 40, y: 50, width: 600, height: 400)),
            screenName: "Main",
            screenKey: "missing-screen",
            relativeFrame: .init(x: 0.2, y: 0.2, width: 0.4, height: 0.4),
            windowRole: "AXWindow",
            windowSubrole: "AXStandardWindow"
        )

        let resolved = snapshot.resolvedFrame(using: [])

        XCTAssertEqual(resolved.origin.x, 40)
        XCTAssertEqual(resolved.origin.y, 50)
        XCTAssertEqual(resolved.width, 600)
        XCTAssertEqual(resolved.height, 400)
    }
}
