import SwiftUI

struct SettingsSection: View {
    @ObservedObject var orchestrator: Orchestrator
    @Binding var launchAtLogin: Bool

    var body: some View {
        VStack(spacing: 0) {
            MenuBarHelpers.sectionDivider

            VStack(spacing: 1) {
                settingRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Auto-restore on screen change",
                    isOn: $orchestrator.autoApplyOnScreenChange
                )
                settingRow(
                    icon: "rectangle.topthird.inset.filled",
                    title: "Snap Bar",
                    isOn: $orchestrator.snapBarController.isEnabled
                )
                settingRow(
                    icon: "power",
                    title: "Launch at Login",
                    isOn: $launchAtLogin
                )
            }
            .padding(.vertical, 4)
            .onChange(of: launchAtLogin) { newValue in
                LoginItemManager.setEnabled(newValue)
            }
        }
    }

    private func settingRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12))

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
