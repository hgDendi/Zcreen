import Foundation
import Cocoa
import Combine

final class ConfigManager: ObservableObject {
    @Published private(set) var configuration: Configuration
    @Published private(set) var configError: String?

    private let configDir: URL
    private let configFileURL: URL
    private var fileMonitor: DispatchSourceFileSystemObject?

    var hasConfigFile: Bool {
        FileManager.default.fileExists(atPath: configFileURL.path)
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/zcreen")
        configFileURL = configDir.appendingPathComponent("config.json")

        // Start with empty config (zero-config mode)
        configuration = Configuration.empty
        configError = nil

        // Ensure directory exists (needed for snapshots)
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        // Load config file if it exists (optional — app works without it)
        if FileManager.default.fileExists(atPath: configFileURL.path) {
            loadConfig()
            watchConfigFile()
        }
    }

    deinit {
        fileMonitor?.cancel()
    }

    func reload() {
        if FileManager.default.fileExists(atPath: configFileURL.path) {
            loadConfig()
            if fileMonitor == nil { watchConfigFile() }
        }
    }

    func createExampleConfig() {
        let example = Configuration(
            version: 1,
            debounceMs: 500,
            screens: [
                ScreenAlias(alias: "dell-portrait", nameContains: "U2723QE"),
                ScreenAlias(alias: "dell-main", nameContains: "UP2720Q"),
                ScreenAlias(alias: "macbook", nameContains: "Built-in"),
            ],
            rules: [
                Rule(app: AppMatcher(bundleId: "com.mitchellh.ghostty", nameContains: nil),
                     targetScreen: "dell-portrait", profileOverrides: nil),
                Rule(app: AppMatcher(bundleId: "com.google.Chrome", nameContains: nil),
                     targetScreen: "dell-main",
                     profileOverrides: ["2-screen": "macbook"]),
            ],
            profiles: [
                "3-screen": ProfileDef(screenCount: 3),
                "2-screen": ProfileDef(screenCount: 2),
            ]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(example)
            try data.write(to: configFileURL)
            loadConfig()
            watchConfigFile()
            Log.config.info("Example config created at \(self.configFileURL.path)")
        } catch {
            Log.config.error("Failed to create example config: \(error.localizedDescription)")
        }
    }

    func openConfigInEditor() {
        if !hasConfigFile { createExampleConfig() }
        NSWorkspace.shared.open(configFileURL)
    }

    var configFilePath: String {
        configFileURL.path
    }

    // MARK: - Private

    private func loadConfig() {
        do {
            let data = try Data(contentsOf: configFileURL)
            let decoded = try JSONDecoder().decode(Configuration.self, from: data)

            // Validate schema
            if let error = validate(decoded) {
                configError = error
                Log.config.error("Config validation failed: \(error)")
                // Still use the decoded config for fields that are valid
                configuration = decoded
                return
            }

            configuration = decoded
            configError = nil
            Log.config.info("Config loaded: \(self.configuration.effectiveRules.count) rules")
        } catch let error as DecodingError {
            let message = decodingErrorMessage(error)
            configError = message
            Log.config.error("Failed to parse config: \(message)")
            configuration = Configuration.empty
        } catch {
            configError = "Cannot read config: \(error.localizedDescription)"
            Log.config.error("Failed to load config: \(error.localizedDescription)")
            configuration = Configuration.empty
        }
    }

    /// Validate config schema, returns error message or nil if valid
    private func validate(_ config: Configuration) -> String? {
        // Check version
        if config.version != 1 {
            return "Unsupported config version: \(config.version) (expected 1)"
        }

        // Check screen alias uniqueness
        if let screens = config.screens {
            let aliases = screens.map(\.alias)
            let unique = Set(aliases)
            if aliases.count != unique.count {
                let dupes = aliases.filter { a in aliases.filter { $0 == a }.count > 1 }
                return "Duplicate screen alias: \(Set(dupes).joined(separator: ", "))"
            }
        }

        // Check rules reference valid screen aliases
        if let rules = config.rules, !rules.isEmpty, config.screens == nil {
            return "Rules defined but no 'screens' section — targetScreen aliases won't match anything"
        }
        if let rules = config.rules, let screens = config.screens {
            let validAliases = Set(screens.map(\.alias))
            for (i, rule) in rules.enumerated() {
                if !validAliases.contains(rule.targetScreen) {
                    return "Rule \(i + 1): targetScreen '\(rule.targetScreen)' not found in screens"
                }
                if let overrides = rule.profileOverrides {
                    for (profile, alias) in overrides {
                        if !validAliases.contains(alias) {
                            return "Rule \(i + 1): profileOverride '\(profile)' references unknown screen '\(alias)'"
                        }
                    }
                }
            }
        }

        // Check rules have at least bundleId or nameContains
        if let rules = config.rules {
            for (i, rule) in rules.enumerated() {
                if rule.app.bundleId == nil && rule.app.nameContains == nil {
                    return "Rule \(i + 1): app matcher needs at least bundleId or nameContains"
                }
            }
        }

        return nil
    }

    private func decodingErrorMessage(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, _):
            return "Missing required field: '\(key.stringValue)'"
        case .typeMismatch(let type, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Type mismatch at '\(path)': expected \(type)"
        case .valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Null value at '\(path)'"
        case .dataCorrupted(let context):
            return "Invalid JSON: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private func watchConfigFile() {
        fileMonitor?.cancel()

        let fd = open(configFileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Log.config.info("Config file changed, reloading...")
            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Timing.configReloadDelay) {
                self?.loadConfig()
                // Re-register monitor to handle atomic writes (rename + create new file)
                self?.watchConfigFile()
            }
        }

        source.setCancelHandler { close(fd) }
        source.resume()
        fileMonitor = source
    }
}
