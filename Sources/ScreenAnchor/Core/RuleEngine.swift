import Foundation

final class RuleEngine {

    struct RuleMatch {
        let rule: Rule
        let bundleId: String
        let targetScreenAlias: String
    }

    func matchRules(configuration: Configuration, screenCount: Int) -> [RuleMatch] {
        let profileName = configuration.profileName(for: screenCount)

        return configuration.effectiveRules.compactMap { rule in
            let targetAlias = rule.resolvedTargetScreen(for: profileName)

            // Only include if we have a bundleId to match
            guard let bundleId = rule.app.bundleId else { return nil }

            return RuleMatch(rule: rule, bundleId: bundleId, targetScreenAlias: targetAlias)
        }
    }

    func matchRule(for bundleId: String?, appName: String?, configuration: Configuration, screenCount: Int) -> RuleMatch? {
        let profileName = configuration.profileName(for: screenCount)

        for rule in configuration.effectiveRules {
            if rule.app.matches(bundleId: bundleId, appName: appName) {
                let targetAlias = rule.resolvedTargetScreen(for: profileName)
                return RuleMatch(rule: rule, bundleId: bundleId ?? "", targetScreenAlias: targetAlias)
            }
        }
        return nil
    }
}
