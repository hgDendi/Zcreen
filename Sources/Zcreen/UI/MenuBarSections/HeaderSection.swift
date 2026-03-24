import SwiftUI

struct HeaderSection: View {
    @ObservedObject var orchestrator: Orchestrator
    @Binding var showSavedApps: Bool
    @State private var secretTapCount = 0
    @State private var lastSecretTap = Date.distantPast

    private var screenDetector: ScreenDetector { orchestrator.screenDetector }
    private var snapshotStore: LayoutSnapshotStore { orchestrator.snapshotStore }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.linearGradient(
                            colors: [.blue.opacity(0.7), .purple.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .onTapGesture {
                    let now = Date()
                    if now.timeIntervalSince(lastSecretTap) > 2 { secretTapCount = 0 }
                    secretTapCount += 1
                    lastSecretTap = now
                    if secretTapCount >= 5 {
                        let configDir = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent(".config/zcreen")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configDir.path)
                        secretTapCount = 0
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Zcreen")
                        .font(.system(size: 13, weight: .semibold))

                    let appCount = snapshotStore.savedAppNames(for: screenDetector.profileKey).count
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { showSavedApps.toggle() }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(screenDetector.screenCount) screen\(screenDetector.screenCount == 1 ? "" : "s") \u{00B7} \(appCount) app\(appCount == 1 ? "" : "s") saved")
                            Image(systemName: showSavedApps ? "chevron.up" : "chevron.down")
                                .font(.system(size: 7, weight: .semibold))
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.quaternary.opacity(0.3))

            if showSavedApps {
                savedAppsSection
            }
        }
    }

    private var savedAppsSection: some View {
        let apps = snapshotStore.savedAppNames(for: screenDetector.profileKey)
        return VStack(alignment: .leading, spacing: 0) {
            if apps.isEmpty {
                Text("No saved layout for current screens")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            } else {
                Text("Saved apps (\(apps.count)):")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                ForEach(apps, id: \.self) { name in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green.opacity(0.6))
                            .frame(width: 5, height: 5)
                        Text(name)
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 1)
                }
                .padding(.bottom, 4)
            }

            MenuBarHelpers.sectionDivider
        }
    }
}
