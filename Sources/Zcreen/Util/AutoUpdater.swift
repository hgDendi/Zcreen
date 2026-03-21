import Cocoa

/// Checks GitHub Releases for new versions. Can download and install updates automatically.
final class AutoUpdater: ObservableObject {
    @Published private(set) var updateAvailable = false
    @Published private(set) var latestVersion = ""
    @Published private(set) var isChecking = false
    @Published private(set) var isDownloading = false

    private(set) var releaseURL: URL?
    private(set) var downloadURL: URL?

    private let currentVersion: String
    private static let repoAPI = "https://api.github.com/repos/hgDendi/Zcreen/releases/latest"

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        // Auto-check on launch (delayed)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.checkIfNeeded()
        }
    }

    // MARK: - Public

    func checkForUpdates() {
        performCheck()
    }

    func openReleasePage() {
        guard let url = releaseURL else { return }
        NSWorkspace.shared.open(url)
    }

    func downloadAndInstall() {
        // Only works when running from a .app bundle
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            Log.general.warning("Auto-update: not running from .app bundle, opening release page instead")
            openReleasePage()
            return
        }
        guard let downloadURL, !isDownloading else { return }
        isDownloading = true

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZcreenUpdate-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        URLSession.shared.downloadTask(with: downloadURL) { [weak self] fileURL, _, error in
            guard let self, let fileURL, error == nil else {
                DispatchQueue.main.async { self?.isDownloading = false }
                Log.general.error("Auto-update download failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            self.installFromZip(fileURL, tempDir: tempDir)
        }.resume()
    }

    // MARK: - Private: check

    private func checkIfNeeded() {
        let lastCheck = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        if Date().timeIntervalSince1970 - lastCheck > 24 * 3600 {
            performCheck()
        }
    }

    private func performCheck() {
        guard !isChecking else { return }
        isChecking = true

        guard let url = URL(string: Self.repoAPI) else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isChecking = false
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")

                guard let data, error == nil,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
                else { return }

                let remote = release.tagName.hasPrefix("v")
                    ? String(release.tagName.dropFirst())
                    : release.tagName

                if self.isNewer(remote, than: self.currentVersion) {
                    self.updateAvailable = true
                    self.latestVersion = remote
                    self.releaseURL = URL(string: release.htmlURL)
                    self.downloadURL = release.assets
                        .first { $0.name.hasSuffix(".zip") }
                        .flatMap { URL(string: $0.browserDownloadURL) }
                    Log.general.info("Update available: \(self.currentVersion) → \(remote)")
                } else {
                    Log.general.info("Up to date: \(self.currentVersion)")
                }
            }
        }.resume()
    }

    // MARK: - Private: install

    private func installFromZip(_ zipFileURL: URL, tempDir: URL) {
        do {
            let zipPath = tempDir.appendingPathComponent("Zcreen.zip")
            try FileManager.default.moveItem(at: zipFileURL, to: zipPath)

            // Unzip
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-o", zipPath.path, "-d", tempDir.path]
            unzip.standardOutput = nil
            unzip.standardError = nil
            try unzip.run()
            unzip.waitUntilExit()

            guard unzip.terminationStatus == 0 else {
                throw UpdateError.unzipFailed
            }

            // Find .app in extracted contents
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            guard let newApp = contents.first(where: { $0.pathExtension == "app" }) else {
                throw UpdateError.noAppFound
            }

            let currentApp = Bundle.main.bundleURL
            let pid = ProcessInfo.processInfo.processIdentifier

            // Shell script: wait for current process to exit → swap → relaunch → cleanup
            let script = """
            #!/bin/bash
            while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done
            rm -rf "\(currentApp.path)"
            cp -R "\(newApp.path)" "\(currentApp.path)"
            open "\(currentApp.path)"
            rm -rf "\(tempDir.path)"
            rm -f "$0"
            """

            let scriptURL = tempDir.appendingPathComponent("zcreen_update.sh")
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755], ofItemAtPath: scriptURL.path
            )

            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/bash")
            launcher.arguments = [scriptURL.path]
            try launcher.run()

            Log.general.info("Auto-update: replacement script launched, terminating app")
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isDownloading = false
            }
            Log.general.error("Auto-update install failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func isNewer(_ remote: String, than local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }

    private enum UpdateError: LocalizedError {
        case unzipFailed, noAppFound

        var errorDescription: String? {
            switch self {
            case .unzipFailed: return "Failed to unzip update"
            case .noAppFound: return "No .app found in downloaded archive"
            }
        }
    }
}

// MARK: - GitHub API Model

private struct GitHubRelease: Codable {
    let tagName: String
    let htmlURL: String
    let assets: [Asset]

    struct Asset: Codable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}
