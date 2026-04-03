import Foundation

final class RuleEngine {

    struct RuleMatch {
        let rule: Rule
        let matchedBundleId: String?
        let targetScreenAlias: String
    }

    func matchRules(configuration: Configuration, screenCount: Int) -> [RuleMatch] {
        let profileName = configuration.profileName(for: screenCount)

        return configuration.effectiveRules.map { rule in
            let targetAlias = rule.resolvedTargetScreen(for: profileName)
            return RuleMatch(rule: rule, matchedBundleId: rule.app.bundleId, targetScreenAlias: targetAlias)
        }
    }

    func matchRule(for bundleId: String?, appName: String?, configuration: Configuration, screenCount: Int) -> RuleMatch? {
        let profileName = configuration.profileName(for: screenCount)

        for rule in configuration.effectiveRules {
            if rule.app.matches(bundleId: bundleId, appName: appName) {
                let targetAlias = rule.resolvedTargetScreen(for: profileName)
                guard let resolvedBundleId = bundleId ?? rule.app.bundleId else { return nil }
                return RuleMatch(rule: rule, matchedBundleId: resolvedBundleId, targetScreenAlias: targetAlias)
            }
        }
        return nil
    }
}
