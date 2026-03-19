import Foundation
import Cocoa
import Combine

final class ConfigManager: ObservableObject {
    @Published private(set) var configuration: Configuration

    private let configDir: URL
    private let configFileURL: URL
    private var fileMonitor: DispatchSourceFileSystemObject?

    var hasConfigFile: Bool {
        FileManager.default.fileExists(atPath: configFileURL.path)
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/screenanchor")
        configFileURL = configDir.appendingPathComponent("config.json")

        // Start with empty config (zero-config mode)
        configuration = Configuration.empty

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
            configuration = try JSONDecoder().decode(Configuration.self, from: data)
            Log.config.info("Config loaded: \(self.configuration.effectiveRules.count) rules")
        } catch {
            Log.config.error("Failed to load config: \(error.localizedDescription). Using defaults.")
            configuration = Configuration.empty
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.loadConfig()
            }
        }

        source.setCancelHandler { close(fd) }
        source.resume()
        fileMonitor = source
    }
}
