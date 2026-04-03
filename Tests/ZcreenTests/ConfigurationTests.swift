import XCTest
@testable import Zcreen

final class ConfigurationTests: XCTestCase {

    func testEmptyConfigHasNoRules() {
        let config = Configuration.empty
        XCTAssertTrue(config.effectiveRules.isEmpty)
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.debounceMilliseconds, 500)
    }

    func testEffectiveRulesReturnsRules() {
        let rules = [
            Rule(app: AppMatcher(bundleId: "com.test", nameContains: nil),
                 targetScreen: "main", profileOverrides: nil)
        ]
        let config = Configuration(version: 1, debounceMs: nil, screens: nil, rules: rules, profiles: nil, windowFilter: nil)
        XCTAssertEqual(config.effectiveRules.count, 1)
    }

    func testDebounceDefaultsTo500() {
        let config = Configuration(version: 1, debounceMs: nil, screens: nil, rules: nil, profiles: nil, windowFilter: nil)
        XCTAssertEqual(config.debounceMilliseconds, 500)
    }

    func testDebounceCustomValue() {
        let config = Configuration(version: 1, debounceMs: 1000, screens: nil, rules: nil, profiles: nil, windowFilter: nil)
        XCTAssertEqual(config.debounceMilliseconds, 1000)
    }

    func testScreenAliasLookup() {
        let screens = [
            ScreenAlias(alias: "macbook", nameContains: "Built-in"),
            ScreenAlias(alias: "dell", nameContains: "U2723QE"),
        ]
        let config = Configuration(version: 1, debounceMs: nil, screens: screens, rules: nil, profiles: nil, windowFilter: nil)

        XCTAssertEqual(config.screenAlias(for: "Built-in Retina Display"), "macbook")
        XCTAssertEqual(config.screenAlias(for: "DELL U2723QE"), "dell")
        XCTAssertNil(config.screenAlias(for: "Unknown Monitor"))
    }

    func testProfileNameLookup() {
        let profiles: [String: ProfileDef] = [
            "2-screen": ProfileDef(screenCount: 2),
            "3-screen": ProfileDef(screenCount: 3),
        ]
        let config = Configuration(version: 1, debounceMs: nil, screens: nil, rules: nil, profiles: profiles, windowFilter: nil)

        XCTAssertEqual(config.profileName(for: 2), "2-screen")
        XCTAssertEqual(config.profileName(for: 3), "3-screen")
        XCTAssertNil(config.profileName(for: 1))
    }

    func testRuleResolvedTargetScreen() {
        let rule = Rule(
            app: AppMatcher(bundleId: "com.test", nameContains: nil),
            targetScreen: "main",
            profileOverrides: ["2-screen": "secondary"]
        )

        XCTAssertEqual(rule.resolvedTargetScreen(for: "2-screen"), "secondary")
        XCTAssertEqual(rule.resolvedTargetScreen(for: "3-screen"), "main")
        XCTAssertEqual(rule.resolvedTargetScreen(for: nil), "main")
    }

    func testConfigDecodingFromJSON() throws {
        let json = """
        {
            "version": 1,
            "debounceMs": 300,
            "screens": [{"alias": "main", "nameContains": "Built-in"}],
            "rules": [{
                "app": {"bundleId": "com.apple.Safari"},
                "targetScreen": "main"
            }]
        }
        """

        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.debounceMilliseconds, 300)
        XCTAssertEqual(config.screens?.count, 1)
        XCTAssertEqual(config.effectiveRules.count, 1)
        XCTAssertEqual(config.effectiveRules.first?.app.bundleId, "com.apple.Safari")
    }

    func testConfigDecodesWindowFilter() throws {
        let json = """
        {
            "version": 1,
            "windowFilter": {
                "excludedApps": [{"bundleId": "com.apple.finder"}],
                "excludedSubroles": ["AXFloatingWindow"],
                "minWidth": 80,
                "minHeight": 60,
                "excludeMinimized": true
            }
        }
        """

        let config = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))

        XCTAssertEqual(config.windowFilter?.excludedApps?.count, 1)
        XCTAssertEqual(config.windowFilter?.excludedSubroles, ["AXFloatingWindow"])
        XCTAssertEqual(config.windowFilter?.minWidth, 80)
        XCTAssertEqual(config.windowFilter?.minHeight, 60)
        XCTAssertEqual(config.windowFilter?.excludeMinimized, true)
    }
}
