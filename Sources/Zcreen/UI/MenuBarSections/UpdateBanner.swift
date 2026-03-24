import SwiftUI

struct UpdateBanner: View {
    @ObservedObject var updater: AutoUpdater

    var body: some View {
        VStack(spacing: 0) {
            if updater.isDownloading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing update...")
                        .font(.system(size: 11))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)

                    Text("v\(updater.latestVersion) Available")
                        .font(.system(size: 11, weight: .semibold))

                    Spacer()

                    if updater.downloadURL != nil {
                        Button { updater.downloadAndInstall() } label: {
                            Text("Update")
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button { updater.openReleasePage() } label: {
                        Image(systemName: "safari")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            MenuBarHelpers.sectionDivider
        }
    }
}
