import Foundation
import CryptoKit

final class LayoutSnapshotStore: ObservableObject {
    @Published private(set) var savedProfileCount: Int = 0

    private let snapshotDir: URL
    private var cache: [String: LayoutSnapshot] = [:]

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/screenanchor/snapshots")
        self.snapshotDir = configDir
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        loadAll()
    }

    func save(snapshot: LayoutSnapshot) {
        cache[snapshot.profileKey] = snapshot
        savedProfileCount = cache.count

        let fileURL = snapshotDir.appendingPathComponent("\(fileNameHash(snapshot.profileKey)).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL)
            Log.snapshot.info("Saved snapshot for '\(snapshot.profileLabel)' (\(snapshot.windows.count) windows)")
        } catch {
            Log.snapshot.error("Failed to save snapshot: \(error.localizedDescription)")
        }
    }

    func load(profileKey: String) -> LayoutSnapshot? {
        cache[profileKey]
    }

    func savedProfiles() -> [(key: String, label: String, windowCount: Int, date: Date)] {
        cache.values
            .sorted { $0.timestamp > $1.timestamp }
            .map { (key: $0.profileKey, label: $0.profileLabel, windowCount: $0.windows.count, date: $0.timestamp) }
    }

    func captureSnapshot(profileKey: String, profileLabel: String, windowManager: WindowManager, screens: [ScreenInfo]) -> LayoutSnapshot {
        let allWindows = windowManager.getAllWindows()
        let windowSnapshots = allWindows.map { win -> WindowSnapshot in
            let screen = findScreen(for: win.frame, in: screens)
            return WindowSnapshot(
                bundleId: win.bundleId ?? "",
                appName: win.appName,
                windowTitle: win.title,
                frame: WindowSnapshot.CodableRect(win.frame),
                screenName: screen?.name ?? "Unknown"
            )
        }

        return LayoutSnapshot(
            profileKey: profileKey,
            profileLabel: profileLabel,
            timestamp: Date(),
            windows: windowSnapshots
        )
    }

    func restoreSnapshot(_ snapshot: LayoutSnapshot, windowManager: WindowManager, excludeBundleIds: Set<String>) {
        let allWindows = windowManager.getAllWindows()

        // Group saved windows by bundleId, preserving order for multi-window apps
        var savedByBundle: [String: [WindowSnapshot]] = [:]
        for w in snapshot.windows where !excludeBundleIds.contains(w.bundleId) {
            savedByBundle[w.bundleId, default: []].append(w)
        }

        // Group running windows by bundleId
        var runningByBundle: [String: [WindowManager.WindowInfo]] = [:]
        for w in allWindows {
            let bid = w.bundleId ?? ""
            if !excludeBundleIds.contains(bid) {
                runningByBundle[bid, default: []].append(w)
            }
        }

        var restored = 0
        for (bundleId, savedWindows) in savedByBundle {
            guard let runningWindows = runningByBundle[bundleId] else { continue }

            // Match windows by index (best effort for multi-window apps)
            for (i, savedWin) in savedWindows.enumerated() where i < runningWindows.count {
                windowManager.moveWindow(runningWindows[i].axWindow, toFrame: savedWin.frame.cgRect)
                restored += 1
            }
        }

        Log.snapshot.info("Restored \(restored) windows from snapshot '\(snapshot.profileLabel)'")
    }

    // MARK: - Private

    private func loadAll() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: snapshotDir, includingPropertiesForKeys: nil)
        else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let snapshot = try? decoder.decode(LayoutSnapshot.self, from: data) {
                cache[snapshot.profileKey] = snapshot
            }
        }
        savedProfileCount = cache.count
        Log.snapshot.info("Loaded \(self.cache.count) cached snapshots")
    }

    /// SHA256 hash of profile key → short hex string for filename
    private func fileNameHash(_ key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private func findScreen(for windowFrame: CGRect, in screens: [ScreenInfo]) -> ScreenInfo? {
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        return screens.first { $0.frame.contains(center) }
    }
}
