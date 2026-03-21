import SwiftUI

struct MenuBarView: View {
    @ObservedObject var orchestrator: Orchestrator
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @State private var hoveredButton: String?
    @State private var accessibilityOK = AccessibilityHelper.isTrusted
    @State private var secretTapCount = 0
    @State private var lastSecretTap = Date.distantPast
    @State private var showSavedApps = false

    private var screenDetector: ScreenDetector { orchestrator.screenDetector }
    private var snapshotStore: LayoutSnapshotStore { orchestrator.snapshotStore }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            if orchestrator.autoUpdater.updateAvailable { updateBanner }
            if !accessibilityOK { permissionBanner }
            screenListSection
            if !orchestrator.lastAction.isEmpty { statusSection }
            settingsSection
            caffeinateSection
            footerSection
        }
        .frame(width: 300)
        .onAppear { accessibilityOK = AccessibilityHelper.isTrusted }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            accessibilityOK = AccessibilityHelper.isTrusted
        }
    }

    // MARK: - Header

    private var headerSection: some View {
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

            sectionDivider
        }
    }

    // MARK: - Update Banner

    private var updateBanner: some View {
        let updater = orchestrator.autoUpdater
        return VStack(spacing: 0) {
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

            sectionDivider
        }
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

    // MARK: - Caffeinate

    private var caffeinateSection: some View {
        let mgr = orchestrator.caffeinateManager
        return VStack(spacing: 0) {
            sectionDivider

            if mgr.isActive {
                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .frame(width: 16)
                    Text("Caffeinate")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(mgr.remainingMinutes) min")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.12))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                    Spacer()
                    Button {
                        mgr.deactivate()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "cup.and.saucer")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text("Caffeinate")
                        .font(.system(size: 12))
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(CaffeinateManager.durations, id: \.minutes) { item in
                            Button {
                                mgr.activate(minutes: item.minutes)
                            } label: {
                                Text(item.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(hoveredButton == "caf-\(item.minutes)" ? 0.1 : 0.05))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .onHover { h in hoveredButton = h ? "caf-\(item.minutes)" : nil }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
                footerButton("About") { showAbout() }

                Spacer()

                if orchestrator.autoUpdater.isChecking {
                    ProgressView()
                        .controlSize(.mini)
                        .padding(.horizontal, 4)
                } else {
                    footerButton("Check for Updates") {
                        orchestrator.autoUpdater.checkForUpdates()
                    }
                }

                footerDot

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
        alert.messageText = "Zcreen"
        alert.informativeText = "Version 1.0.0\n\nMulti-screen window manager for macOS.\nAutomatically saves and restores window layouts when screens change.\n\nNo configuration needed \u{2014} just plug/unplug your displays."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
