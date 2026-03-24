import XCTest
@testable import Zcreen

final class ConstantsTests: XCTestCase {

    func testSnapBarConstants() {
        XCTAssertGreaterThan(Constants.SnapBar.highFrequencyInterval, 0)
        XCTAssertGreaterThan(Constants.SnapBar.lowFrequencyInterval, Constants.SnapBar.highFrequencyInterval)
        XCTAssertGreaterThan(Constants.SnapBar.dragThreshold, 0)
        XCTAssertGreaterThan(Constants.SnapBar.titleBarHeight, 0)
    }

    func testLayoutConstants() {
        XCTAssertGreaterThan(Constants.Layout.windowGap, 0)
    }

    func testPanelConstants() {
        XCTAssertGreaterThan(Constants.Panel.horizontalPadding, 0)
        XCTAssertGreaterThan(Constants.Panel.verticalPadding, 0)
        XCTAssertGreaterThan(Constants.Panel.groupGap, 0)
    }

    func testTimingConstants() {
        XCTAssertGreaterThan(Constants.Timing.snapshotMaxRetries, 0)
        XCTAssertGreaterThan(Constants.Timing.snapshotRetryBaseDelay, 0)
        XCTAssertGreaterThan(Constants.Timing.appLaunchPollMaxAttempts, 0)
        XCTAssertGreaterThan(Constants.Timing.appLaunchPollInterval, 0)
    }
}
