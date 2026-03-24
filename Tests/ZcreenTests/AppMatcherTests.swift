import XCTest
@testable import Zcreen

final class AppMatcherTests: XCTestCase {

    func testMatchesByBundleId() {
        let matcher = AppMatcher(bundleId: "com.apple.Safari", nameContains: nil)
        XCTAssertTrue(matcher.matches(bundleId: "com.apple.Safari", appName: "Safari"))
        XCTAssertFalse(matcher.matches(bundleId: "com.google.Chrome", appName: "Chrome"))
    }

    func testMatchesByNameContains() {
        let matcher = AppMatcher(bundleId: nil, nameContains: "Chrome")
        XCTAssertTrue(matcher.matches(bundleId: "com.google.Chrome", appName: "Google Chrome"))
        XCTAssertFalse(matcher.matches(bundleId: "com.apple.Safari", appName: "Safari"))
    }

    func testMatchesByNameContainsCaseInsensitive() {
        let matcher = AppMatcher(bundleId: nil, nameContains: "chrome")
        XCTAssertTrue(matcher.matches(bundleId: nil, appName: "Google Chrome"))
    }

    func testMatchesBundleIdTakesPriority() {
        let matcher = AppMatcher(bundleId: "com.apple.Safari", nameContains: "Chrome")
        // Should match by bundleId even though name doesn't contain "Chrome"
        XCTAssertTrue(matcher.matches(bundleId: "com.apple.Safari", appName: "Safari"))
        // Should also match by name
        XCTAssertTrue(matcher.matches(bundleId: "com.other", appName: "Chrome"))
    }

    func testNoMatchWhenBothNil() {
        let matcher = AppMatcher(bundleId: nil, nameContains: nil)
        XCTAssertFalse(matcher.matches(bundleId: "com.test", appName: "Test"))
    }

    func testNoMatchWithNilInputs() {
        let matcher = AppMatcher(bundleId: "com.test", nameContains: nil)
        XCTAssertFalse(matcher.matches(bundleId: nil, appName: nil))
    }
}
