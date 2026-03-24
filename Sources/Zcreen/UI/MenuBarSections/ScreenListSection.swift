import SwiftUI

struct ScreenListSection: View {
    let screens: [ScreenInfo]
    @Binding var hoveredButton: String?

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(screens.enumerated()), id: \.element.id) { index, screen in
                screenRow(screen, index: index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func screenRow(_ screen: ScreenInfo, index: Int) -> some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(MenuBarHelpers.screenColor(index))
                    .frame(width: 3, height: 28)

                Image(systemName: screen.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(MenuBarHelpers.screenColor(index))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(screen.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        MenuBarHelpers.resolutionBadge(screen)
                        if screen.isPortrait {
                            MenuBarHelpers.metaBadge("portrait", icon: "rotate.right")
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(hoveredButton == "screen-\(index)" ? 0.12 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in hoveredButton = hovering ? "screen-\(index)" : nil }
    }
}
