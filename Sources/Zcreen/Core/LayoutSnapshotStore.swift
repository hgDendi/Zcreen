import Foundation
import Cocoa
import CryptoKit

final class LayoutSnapshotStore: ObservableObject {
    @Published private(set) var savedProfileCount: Int = 0

    private let snapshotDir: URL
    private var cache: [String: LayoutSnapshot] = [:]

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/zcreen/snapshots")
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

    func savedAppNames(for profileKey: String) -> [String] {
        guard let snapshot = cache[profileKey] else { return [] }
        var seen = Set<String>()
        return snapshot.windows.compactMap { w in
            guard !w.appName.isEmpty, seen.insert(w.appName).inserted else { return nil }
            return w.appName
        }
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
        let missed = doRestore(snapshot: snapshot, windowManager: windowManager, excludeBundleIds: excludeBundleIds)

        if !missed.isEmpty {
            scheduleRetry(snapshot: snapshot, windowManager: windowManager,
                          excludeBundleIds: excludeBundleIds, missed: missed, attempt: 1)
        }
    }

    // MARK: - Exponential backoff retry

    private func scheduleRetry(snapshot: LayoutSnapshot, windowManager: WindowManager,
                               excludeBundleIds: Set<String>, missed: [String], attempt: Int) {
        let maxRetries = Constants.Timing.snapshotMaxRetries
        guard attempt <= maxRetries else {
            Log.snapshot.info("RESTORE: gave up after \(maxRetries) retries, \(missed.count) apps still inaccessible")
            return
        }

        // Exponential backoff: 1s → 2s → 4s
        let delay = Constants.Timing.snapshotRetryBaseDelay * pow(2.0, Double(attempt - 1))
        Log.snapshot.info("RESTORE: \(missed.count) apps missed, retry \(attempt)/\(maxRetries) in \(delay)s...")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            let stillMissed = self?.doRestore(snapshot: snapshot, windowManager: windowManager,
                                             excludeBundleIds: excludeBundleIds) ?? []
            if !stillMissed.isEmpty {
                self?.scheduleRetry(snapshot: snapshot, windowManager: windowManager,
                                    excludeBundleIds: excludeBundleIds, missed: stillMissed, attempt: attempt + 1)
            }
        }
    }

    /// Returns bundle IDs of apps that were in snapshot but couldn't be found/moved.
    @discardableResult
    private func doRestore(snapshot: LayoutSnapshot, windowManager: WindowManager, excludeBundleIds: Set<String>) -> [String] {
        let allWindows = windowManager.getAllWindows()
        Log.snapshot.info("RESTORE: snapshot has \(snapshot.windows.count) saved, \(allWindows.count) running")

        var savedByBundle: [String: [WindowSnapshot]] = [:]
        for w in snapshot.windows where !excludeBundleIds.contains(w.bundleId) {
            savedByBundle[w.bundleId, default: []].append(w)
        }

        var runningByBundle: [String: [WindowManager.WindowInfo]] = [:]
        for w in allWindows {
            let bid = w.bundleId ?? ""
            if !excludeBundleIds.contains(bid) {
                runningByBundle[bid, default: []].append(w)
            }
        }

        var restored = 0
        var missed: [String] = []

        for (bundleId, savedWindows) in savedByBundle {
            guard let runningWindows = runningByBundle[bundleId] else {
                if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId }) {
                    missed.append(bundleId)
                    Log.snapshot.info("RESTORE: \(savedWindows.first?.appName ?? bundleId) — running but AX returned 0 windows")
                }
                continue
            }

            for (i, savedWin) in savedWindows.enumerated() where i < runningWindows.count {
                let target = savedWin.frame.cgRect
                Log.snapshot.info("RESTORE: \(savedWin.appName) → (\(Int(target.origin.x)),\(Int(target.origin.y)),\(Int(target.width))x\(Int(target.height)))")
                windowManager.moveWindow(runningWindows[i].axWindow, toFrame: target)
                restored += 1
            }
        }

        Log.snapshot.info("RESTORE: moved \(restored) windows for '\(snapshot.profileLabel)'")
        return missed
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
