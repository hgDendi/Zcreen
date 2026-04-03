import XCTest
import CoreGraphics
@testable import Zcreen

final class CoordinateConverterTests: XCTestCase {

    func testNsPointConvertsUsingExplicitMainScreenReference() {
        let mainScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let nsPoint = NSPoint(x: 100, y: 200)

        let accessibilityPoint = CoordinateConverter.nsToAccessibility(nsPoint, mainScreenFrame: mainScreenFrame)

        XCTAssertEqual(accessibilityPoint.x, 100)
        XCTAssertEqual(accessibilityPoint.y, 782)
    }

    func testRoundTripSupportsNegativeXSecondaryDisplay() {
        let mainScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let original = NSPoint(x: -640, y: 320)

        let accessibilityPoint = CoordinateConverter.nsToAccessibility(original, mainScreenFrame: mainScreenFrame)
        let roundTrip = CoordinateConverter.accessibilityToNS(accessibilityPoint, mainScreenFrame: mainScreenFrame)

        XCTAssertEqual(roundTrip.x, original.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, original.y, accuracy: 0.001)
    }

    func testNsFrameConvertsForUpperStackedDisplay() {
        let mainScreenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let upperVisibleFrame = CGRect(x: 0, y: 982, width: 1728, height: 1117)

        let accessibilityFrame = CoordinateConverter.nsToAccessibility(upperVisibleFrame, mainScreenFrame: mainScreenFrame)

        XCTAssertEqual(accessibilityFrame.origin.x, 0)
        XCTAssertEqual(accessibilityFrame.origin.y, -1117)
        XCTAssertEqual(accessibilityFrame.width, 1728)
        XCTAssertEqual(accessibilityFrame.height, 1117)
    }

    func testMainScreenFrameUsesZeroOriginScreenWhenPrimaryScreenChanges() {
        let leftScreen = CGRect(x: -1512, y: 0, width: 1512, height: 982)
        let mainScreen = CGRect(x: 0, y: 0, width: 2560, height: 1440)

        let resolvedMainScreen = CoordinateConverter.mainScreenFrame(from: [leftScreen, mainScreen])

        XCTAssertEqual(resolvedMainScreen, mainScreen)
    }

    func testScreenContainingAccessibilityPointFindsUpperDisplay() {
        let mainScreen = makeScreen(
            displayID: 1,
            name: "Built-in Retina Display",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
        )
        let upperScreen = makeScreen(
            displayID: 2,
            name: "Studio Display",
            frame: CGRect(x: 0, y: 982, width: 1728, height: 1117)
        )

        let screen = CoordinateConverter.screenContainingAccessibilityPoint(
            CGPoint(x: 400, y: -400),
            in: [mainScreen, upperScreen]
        )

        XCTAssertEqual(screen?.uniqueKey, upperScreen.uniqueKey)
    }

    private func makeScreen(displayID: CGDirectDisplayID, name: String, frame: CGRect) -> ScreenInfo {
        ScreenInfo(
            displayID: displayID,
            name: name,
            frame: frame,
            isBuiltIn: displayID == 1,
            position: .single,
            vendorID: displayID,
            modelID: 100 + displayID,
            serialNumber: 1000 + displayID
        )
    }
}
