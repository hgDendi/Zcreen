import Foundation

struct ScreenAlias: Codable {
    let alias: String
    let nameContains: String
}

struct ProfileDef: Codable {
    let screenCount: Int
}

struct WindowFilterConfig: Codable {
    let excludedApps: [AppMatcher]?
    let excludedRoles: [String]?
    let excludedSubroles: [String]?
    let minWidth: Double?
    let minHeight: Double?
    let excludeMinimized: Bool?
}

struct Configuration: Codable {
    let version: Int
    let debounceMs: Int?
    let screens: [ScreenAlias]?
    let rules: [Rule]?
    let profiles: [String: ProfileDef]?
    let windowFilter: WindowFilterConfig?

    var debounceMilliseconds: Int {
        debounceMs ?? 500
    }

    var effectiveRules: [Rule] {
        rules ?? []
    }

    func screenAlias(for screenName: String) -> String? {
        screens?.first { screenName.localizedCaseInsensitiveContains($0.nameContains) }?.alias
    }

    func profileName(for screenCount: Int) -> String? {
        profiles?.first { $0.value.screenCount == screenCount }?.key
    }

    /// Zero-config default: no rules, no screen aliases. Snapshots work automatically.
    static let empty = Configuration(
        version: 1,
        debounceMs: 500,
        screens: nil,
        rules: nil,
        profiles: nil,
        windowFilter: nil
    )
}
