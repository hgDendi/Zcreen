import XCTest
@testable import Zcreen

final class CoordinateConverterTests: XCTestCase {

    func testNsToCGPoint() {
        // CoordinateConverter uses primary screen height internally
        // We test the math: CG.y = primaryH - NS.y
        let primaryH = CoordinateConverter.primaryScreenHeight
        guard primaryH > 0 else { return } // Skip if no screens

        let nsPoint = NSPoint(x: 100, y: 200)
        let cgPoint = CoordinateConverter.nsToCG(nsPoint)

        XCTAssertEqual(cgPoint.x, 100)
        XCTAssertEqual(cgPoint.y, primaryH - 200)
    }

    func testCgToNSPoint() {
        let primaryH = CoordinateConverter.primaryScreenHeight
        guard primaryH > 0 else { return }

        let cgPoint = CGPoint(x: 100, y: 200)
        let nsPoint = CoordinateConverter.cgToNS(cgPoint)

        XCTAssertEqual(nsPoint.x, 100)
        XCTAssertEqual(nsPoint.y, primaryH - 200)
    }

    func testRoundTrip() {
        let primaryH = CoordinateConverter.primaryScreenHeight
        guard primaryH > 0 else { return }

        let original = NSPoint(x: 42, y: 777)
        let cgPoint = CoordinateConverter.nsToCG(original)
        let roundTrip = CoordinateConverter.cgToNS(cgPoint)

        XCTAssertEqual(roundTrip.x, original.x, accuracy: 0.001)
        XCTAssertEqual(roundTrip.y, original.y, accuracy: 0.001)
    }

    func testNsToCGFrame() {
        let primaryH = CoordinateConverter.primaryScreenHeight
        guard primaryH > 0 else { return }

        let nsFrame = NSRect(x: 100, y: 200, width: 800, height: 600)
        let cgFrame = CoordinateConverter.nsToCG(nsFrame)

        XCTAssertEqual(cgFrame.origin.x, 100)
        XCTAssertEqual(cgFrame.origin.y, primaryH - 200 - 600)
        XCTAssertEqual(cgFrame.width, 800)
        XCTAssertEqual(cgFrame.height, 600)
    }
}
