import XCTest
@testable import Zcreen

final class RuleEngineTests: XCTestCase {

    private let engine = RuleEngine()

    private func makeConfig(rules: [Rule], screens: [ScreenAlias]? = nil,
                            profiles: [String: ProfileDef]? = nil) -> Configuration {
        Configuration(version: 1, debounceMs: 500, screens: screens, rules: rules, profiles: profiles, windowFilter: nil)
    }

    func testMatchRulesReturnsMatchesForBundleId() {
        let rules = [
            Rule(app: AppMatcher(bundleId: "com.apple.Safari", nameContains: nil),
                 targetScreen: "main", profileOverrides: nil)
        ]
        let config = makeConfig(rules: rules)
        let matches = engine.matchRules(configuration: config, screenCount: 2)

        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].matchedBundleId, "com.apple.Safari")
        XCTAssertEqual(matches[0].targetScreenAlias, "main")
    }

    func testMatchRulesIncludesRulesWithoutBundleId() {
        let rules = [
            Rule(app: AppMatcher(bundleId: nil, nameContains: "Chrome"),
                 targetScreen: "main", profileOverrides: nil)
        ]
        let config = makeConfig(rules: rules)
        let matches = engine.matchRules(configuration: config, screenCount: 2)

        XCTAssertEqual(matches.count, 1)
        XCTAssertNil(matches[0].matchedBundleId)
    }

    func testMatchRuleUsesProfileOverride() {
        let rules = [
            Rule(app: AppMatcher(bundleId: "com.google.Chrome", nameContains: nil),
                 targetScreen: "main",
                 profileOverrides: ["2-screen": "secondary"])
        ]
        let profiles: [String: ProfileDef] = ["2-screen": ProfileDef(screenCount: 2)]
        let config = makeConfig(rules: rules, profiles: profiles)

        let match = engine.matchRule(for: "com.google.Chrome", appName: "Chrome",
                                     configuration: config, screenCount: 2)

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.targetScreenAlias, "secondary")
    }

    func testMatchRuleFallsBackToDefaultTarget() {
        let rules = [
            Rule(app: AppMatcher(bundleId: "com.google.Chrome", nameContains: nil),
                 targetScreen: "main",
                 profileOverrides: ["2-screen": "secondary"])
        ]
        let profiles: [String: ProfileDef] = ["2-screen": ProfileDef(screenCount: 2)]
        let config = makeConfig(rules: rules, profiles: profiles)

        // screenCount=3 doesn't match any profile, so fallback to default targetScreen
        let match = engine.matchRule(for: "com.google.Chrome", appName: "Chrome",
                                     configuration: config, screenCount: 3)

        XCTAssertNotNil(match)
        XCTAssertEqual(match?.targetScreenAlias, "main")
    }

    func testMatchRuleReturnsNilForUnknownApp() {
        let rules = [
            Rule(app: AppMatcher(bundleId: "com.apple.Safari", nameContains: nil),
                 targetScreen: "main", profileOverrides: nil)
        ]
        let config = makeConfig(rules: rules)

        let match = engine.matchRule(for: "com.unknown.app", appName: "Unknown",
                                     configuration: config, screenCount: 1)

        XCTAssertNil(match)
    }

    func testMatchRuleByNameContains() {
        let rules = [
            Rule(app: AppMatcher(bundleId: nil, nameContains: "Slack"),
                 targetScreen: "main", profileOverrides: nil)
        ]
        let config = makeConfig(rules: rules)

        let match = engine.matchRule(for: "com.tinyspeck.slackmacgap", appName: "Slack",
                                     configuration: config, screenCount: 1)

        XCTAssertNotNil(match)
    }

    func testEmptyRulesReturnsEmpty() {
        let config = Configuration.empty
        let matches = engine.matchRules(configuration: config, screenCount: 2)
        XCTAssertTrue(matches.isEmpty)
    }
}
