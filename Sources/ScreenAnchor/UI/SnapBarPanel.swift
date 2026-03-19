import SwiftUI
import Cocoa

// MARK: - Observable State

final class SnapBarState: ObservableObject {
    @Published var highlightedIndex: Int?
    let presets: [LayoutPreset] = LayoutPreset.all
}

// MARK: - NSPanel wrapper

final class SnapBarPanel {
    let panel: NSPanel
    let state: SnapBarState

    static let cellWidth: CGFloat = 52
    static let cellIconHeight: CGFloat = 34
    static let cellTotalHeight: CGFloat = 52
    static let cellGap: CGFloat = 6
    static let groupGap: CGFloat = 16
    static let panelPadding: CGFloat = 16
    static let panelHeight: CGFloat = 72

    init() {
        state = SnapBarState()

        let panelWidth = Self.computePanelWidth()
        let rect = NSRect(x: 0, y: 0, width: panelWidth, height: Self.panelHeight)

        panel = NSPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver          // above everything
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.ignoresMouseEvents = true      // let events pass through to the window being dragged

        let hostingView = NSHostingView(rootView: SnapBarContentView(state: state))
        hostingView.frame = rect
        panel.contentView = hostingView
    }

    func show(on screen: NSScreen) {
        let panelWidth = panel.frame.width
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        // Position just below menu bar
        let menuBarBottom = visibleFrame.maxY
        let y = menuBarBottom - Self.panelHeight - 6

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        state.highlightedIndex = nil
    }

    /// Hit test: which preset is the mouse over? (screenPoint in NS coords)
    func presetIndex(at screenPoint: NSPoint) -> Int? {
        let pf = panel.frame
        guard screenPoint.x >= pf.minX && screenPoint.x <= pf.maxX &&
              screenPoint.y >= pf.minY && screenPoint.y <= pf.maxY
        else { return nil }

        let localX = screenPoint.x - pf.origin.x - Self.panelPadding
        // Vertical: just check if within panel (already checked above)

        var x: CGFloat = 0
        var lastGroup = -1

        for (i, preset) in state.presets.enumerated() {
            if preset.group != lastGroup {
                if lastGroup >= 0 { x += Self.groupGap }
                lastGroup = preset.group
            } else {
                x += Self.cellGap
            }

            if localX >= x && localX < x + Self.cellWidth {
                return i
            }
            x += Self.cellWidth
        }
        return nil
    }

    private static func computePanelWidth() -> CGFloat {
        let presets = LayoutPreset.all
        var width: CGFloat = panelPadding * 2
        var lastGroup = -1

        for (i, preset) in presets.enumerated() {
            if preset.group != lastGroup {
                if i > 0 { width += groupGap }
                lastGroup = preset.group
            } else {
                width += cellGap
            }
            width += cellWidth
        }
        return width
    }
}

// MARK: - SwiftUI

struct SnapBarContentView: View {
    @ObservedObject var state: SnapBarState

    var body: some View {
        HStack(spacing: 0) {
            let groups = groupedPresets()
            ForEach(Array(groups.enumerated()), id: \.offset) { gIdx, group in
                if gIdx > 0 { groupDivider }
                HStack(spacing: 6) {
                    ForEach(group) { preset in
                        let idx = state.presets.firstIndex(of: preset)!
                        PresetCellView(
                            preset: preset,
                            isHighlighted: state.highlightedIndex == idx
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }

    private var groupDivider: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 7.5)
    }

    private func groupedPresets() -> [[LayoutPreset]] {
        var result: [[LayoutPreset]] = []
        var current: [LayoutPreset] = []
        var last = -1
        for p in state.presets {
            if p.group != last && !current.isEmpty {
                result.append(current)
                current = []
            }
            current.append(p)
            last = p.group
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

struct PresetCellView: View {
    let preset: LayoutPreset
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 3) {
            // Visual icon
            ZStack {
                ForEach(Array(preset.zones.enumerated()), id: \.offset) { i, zone in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(fillColor(i))
                        .frame(width: zone.width * 44, height: zone.height * 30)
                        .position(x: zone.midX * 44, y: zone.midY * 30)
                }
            }
            .frame(width: 44, height: 30)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isHighlighted ? Color.blue.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 0.5)
            )

            // Label
            Text(preset.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(isHighlighted ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: 52, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isHighlighted ? Color.blue.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(isHighlighted ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isHighlighted ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
    }

    private func fillColor(_ index: Int) -> Color {
        if index == preset.activeZone {
            return isHighlighted ? .blue : .blue.opacity(0.5)
        }
        return Color.primary.opacity(isHighlighted ? 0.15 : 0.08)
    }
}
