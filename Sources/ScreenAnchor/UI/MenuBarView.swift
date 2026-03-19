import SwiftUI

struct MenuBarView: View {
    @ObservedObject var orchestrator: Orchestrator
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var hoveredButton: String?
    @State private var accessibilityOK = AccessibilityHelper.isTrusted

    private var screenDetector: ScreenDetector { orchestrator.screenDetector }
    private var snapshotStore: LayoutSnapshotStore { orchestrator.snapshotStore }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if !accessibilityOK { permissionBanner }
            screenListSection
            if !orchestrator.lastAction.isEmpty { statusSection }
            settingsSection
            footerSection
        }
        .frame(width: 300)
        .onAppear { accessibilityOK = AccessibilityHelper.isTrusted }
    }

    // MARK: - Header

    private var headerSection: some View {
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

            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenAnchor")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(screenDetector.screenCount) screen\(screenDetector.screenCount == 1 ? "" : "s") \u{00B7} \(snapshotStore.savedProfileCount) layout\(snapshotStore.savedProfileCount == 1 ? "" : "s") saved")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.quaternary.opacity(0.3))
    }

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        Button {
            AccessibilityHelper.openAccessibilitySettings()
            // Recheck after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                accessibilityOK = AccessibilityHelper.isTrusted
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Accessibility Permission Required")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Click to open System Settings")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.gradient)
                    .padding(.horizontal, 8)
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    // MARK: - Screen List

    private var screenListSection: some View {
        VStack(spacing: 6) {
            ForEach(Array(screenDetector.screens.enumerated()), id: \.element.id) { index, screen in
                screenRow(screen, index: index)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func screenRow(_ screen: ScreenInfo, index: Int) -> some View {
        Button {
            openDisplaySettings()
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(screenColor(index))
                    .frame(width: 3, height: 28)

                Image(systemName: screen.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(screenColor(index))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(screen.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        resolutionBadge(screen)
                        if screen.isPortrait {
                            metaBadge("portrait", icon: "rotate.right")
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

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.green.opacity(0.7))
            Text(orchestrator.lastAction)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(spacing: 0) {
            sectionDivider

            VStack(spacing: 1) {
                settingRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Auto-restore on screen change",
                    isOn: $orchestrator.autoApplyOnScreenChange
                )
                settingRow(
                    icon: "rectangle.topthird.inset.filled",
                    title: "Snap Bar (drag window to snap)",
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

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            sectionDivider

            HStack(spacing: 0) {
                footerButton("Config") {
                    orchestrator.configManager.openConfigInEditor()
                }

                if orchestrator.configManager.hasConfigFile {
                    footerDot
                    footerButton("Reload") {
                        orchestrator.configManager.reload()
                    }
                }

                footerDot

                footerButton("About") { showAbout() }

                Spacer()

                footerButton("Quit", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.2))
        }
    }

    private func footerButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(role == .destructive ? .red.opacity(0.8) : .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { hoveredButton = title } else { hoveredButton = nil }
        }
    }

    private var footerDot: some View {
        Text("\u{00B7}")
            .font(.system(size: 11))
            .foregroundStyle(.quaternary)
            .padding(.horizontal, 6)
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
    }

    private func screenColor(_ index: Int) -> Color {
        [.blue, .purple, .teal, .orange, .pink][index % 5]
    }

    private func resolutionBadge(_ screen: ScreenInfo) -> some View {
        Text("\(Int(screen.frame.width)) \u{00D7} \(Int(screen.frame.height))")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.secondary.opacity(0.1))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }

    private func metaBadge(_ text: String, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 7))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(.secondary.opacity(0.1))
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
    }

    private func openDisplaySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "ScreenAnchor"
        alert.informativeText = "Version 1.0.0\n\nMulti-screen window manager for macOS.\nAutomatically saves and restores window layouts when screens change.\n\nNo configuration needed \u{2014} just plug/unplug your displays."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
