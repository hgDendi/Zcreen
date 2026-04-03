import XCTest
@testable import Zcreen

/// Tests for ConfigManager validation logic (indirectly via Configuration parsing)
final class ConfigValidationTests: XCTestCase {

    func testValidConfigDecodesSuccessfully() throws {
        let json = """
        {
            "version": 1,
            "screens": [{"alias": "main", "nameContains": "Built-in"}],
            "rules": [{
                "app": {"bundleId": "com.apple.Safari"},
                "targetScreen": "main"
            }]
        }
        """
        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.effectiveRules.count, 1)
    }

    func testInvalidJSONFailsDecoding() {
        let json = "{ invalid json }"
        XCTAssertThrowsError(try JSONDecoder().decode(Configuration.self, from: Data(json.utf8)))
    }

    func testMissingVersionFieldFails() {
        let json = """
        {
            "screens": [{"alias": "main", "nameContains": "Built-in"}]
        }
        """
        XCTAssertThrowsError(try JSONDecoder().decode(Configuration.self, from: Data(json.utf8)))
    }

    func testRuleWithoutAppMatcherFields() throws {
        let json = """
        {
            "version": 1,
            "screens": [{"alias": "main", "nameContains": "Built-in"}],
            "rules": [{
                "app": {},
                "targetScreen": "main"
            }]
        }
        """
        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        // Rule with empty app matcher — both bundleId and nameContains are nil
        XCTAssertNil(config.effectiveRules.first?.app.bundleId)
        XCTAssertNil(config.effectiveRules.first?.app.nameContains)
    }

    func testRuleProfileOverridesDecoding() throws {
        let json = """
        {
            "version": 1,
            "screens": [
                {"alias": "main", "nameContains": "Built-in"},
                {"alias": "ext", "nameContains": "Dell"}
            ],
            "rules": [{
                "app": {"bundleId": "com.google.Chrome"},
                "targetScreen": "main",
                "profileOverrides": {"2-screen": "ext"}
            }],
            "profiles": {"2-screen": {"screenCount": 2}}
        }
        """
        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        let rule = config.effectiveRules.first
        XCTAssertEqual(rule?.resolvedTargetScreen(for: "2-screen"), "ext")
        XCTAssertEqual(rule?.resolvedTargetScreen(for: nil), "main")
    }

    func testWindowFilterDecodesExcludedApps() throws {
        let json = """
        {
            "version": 1,
            "windowFilter": {
                "excludedApps": [{"nameContains": "Finder"}],
                "excludedSubroles": ["AXFloatingWindow"]
            }
        }
        """

        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))

        XCTAssertEqual(config.windowFilter?.excludedApps?.first?.nameContains, "Finder")
        XCTAssertEqual(config.windowFilter?.excludedSubroles, ["AXFloatingWindow"])
    }
}
