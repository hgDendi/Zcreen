import Foundation

final class MenuSettingsStore {
    enum Key: String {
        case autoApplyOnScreenChange = "menu.autoApplyOnScreenChange"
        case autoApplyOnAppLaunch = "menu.autoApplyOnAppLaunch"
        case snapBarEnabled = "menu.snapBarEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func bool(for key: Key, default defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key.rawValue) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key.rawValue)
    }

    func set(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}
