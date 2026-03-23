import SwiftUI
import Cocoa

// MARK: - State

final class SnapBarState: ObservableObject {
    @Published var highlightedGroupIndex: Int?
    @Published var highlightedZoneIndex: Int?
    let groups: [PresetGroup]

    init(groups: [PresetGroup]) {
        self.groups = groups
    }

    var highlightedPreset: LayoutPreset? {
        guard let gi = highlightedGroupIndex, let zi = highlightedZoneIndex,
              gi < groups.count, zi < groups[gi].zones.count
        else { return nil }
        return groups[gi].zones[zi].preset
    }
}

// MARK: - Panel

final class SnapBarPanel {
    let panel: NSPanel
    let state: SnapBarState

    static let groupGap: CGFloat = 22
    static let panelPadding: CGFloat = 22   // horizontal padding
    static let verticalPadding: CGFloat = 18 // must match SwiftUI .padding(.vertical, 18)
    static let labelHeight: CGFloat = 18
    static let iconLabelGap: CGFloat = 6

    private var groupOrigins: [(x: CGFloat, iconWidth: CGFloat, iconHeight: CGFloat)] = []

    init(groups: [PresetGroup]) {
        state = SnapBarState(groups: groups)
        let (panelWidth, panelHeight, origins) = Self.computeLayout(groups: state.groups)
        groupOrigins = origins

        let rect = NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight)
        panel = NSPanel(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: SnapBarContentView(state: state))
        hostingView.frame = rect
        panel.contentView = hostingView
    }

    func show(on screen: NSScreen) {
        let w = panel.frame.width
        let sf = screen.frame
        let vf = screen.visibleFrame
        let x = sf.origin.x + (sf.width - w) / 2
        let y = vf.maxY - panel.frame.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
        state.highlightedGroupIndex = nil
        state.highlightedZoneIndex = nil
    }

    /// Hit test: returns the preset at the given NS screen point, or nil.
    func presetAt(_ pt: NSPoint) -> LayoutPreset? {
        let pf = panel.frame
        guard pf.contains(pt) else { return nil }

        let localX = pt.x - pf.origin.x - Self.panelPadding
        let panelLocalY = pt.y - pf.origin.y  // 0 = panel bottom

        for (gi, origin) in groupOrigins.enumerated() {
            let group = state.groups[gi]
            // Expand X hit area by 4pt on each side for easier targeting
            guard localX >= origin.x - 4 && localX < origin.x + origin.iconWidth + 4 else { continue }

            let cellLocalX = max(0, min(1, (localX - origin.x) / origin.iconWidth))

            // Accept hits anywhere in the cell height (icon + label area)
            let cellTopY = pf.height - Self.verticalPadding
            let cellBottomY = Self.verticalPadding
            guard panelLocalY >= cellBottomY && panelLocalY <= cellTopY else { continue }

            // Map Y to icon zone coords (0=top, 1=bottom), clamped
            let iconTopY = cellTopY
            let iconBottomY = iconTopY - origin.iconHeight
            let rawY = 1.0 - (panelLocalY - iconBottomY) / origin.iconHeight
            let cellLocalY = max(0, min(1, rawY))

            for (zi, zone) in group.zones.enumerated() {
                if zone.hitRect.contains(CGPoint(x: cellLocalX, y: cellLocalY)) {
                    state.highlightedGroupIndex = gi
                    state.highlightedZoneIndex = zi
                    return zone.preset
                }
            }
        }

        state.highlightedGroupIndex = nil
        state.highlightedZoneIndex = nil
        return nil
    }

    /// Update highlight state (returns preset or nil)
    @discardableResult
    func updateHighlight(at pt: NSPoint) -> LayoutPreset? {
        let result = presetAt(pt)
        if result == nil {
            state.highlightedGroupIndex = nil
            state.highlightedZoneIndex = nil
        }
        return result
    }

    // MARK: - Layout calculation

    private static func computeLayout(groups: [PresetGroup])
        -> (width: CGFloat, height: CGFloat, origins: [(x: CGFloat, iconWidth: CGFloat, iconHeight: CGFloat)])
    {
        var origins: [(x: CGFloat, iconWidth: CGFloat, iconHeight: CGFloat)] = []
        var x: CGFloat = 0
        var maxIconH: CGFloat = 0

        for (i, g) in groups.enumerated() {
            if i > 0 { x += groupGap }
            origins.append((x: x, iconWidth: g.iconWidth, iconHeight: g.iconHeight))
            x += g.iconWidth
            maxIconH = max(maxIconH, g.iconHeight)
        }

        let totalWidth = x + panelPadding * 2
        let totalHeight = maxIconH + labelHeight + iconLabelGap + verticalPadding * 2
        return (totalWidth, totalHeight, origins)
    }
}

// MARK: - SwiftUI

struct SnapBarContentView: View {
    @ObservedObject var state: SnapBarState

    var body: some View {
        HStack(spacing: 22) {
            ForEach(Array(state.groups.enumerated()), id: \.element.id) { gi, group in
                GroupCellView(
                    group: group,
                    isGroupHighlighted: state.highlightedGroupIndex == gi,
                    activeZoneIndex: state.highlightedGroupIndex == gi ? state.highlightedZoneIndex : nil
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}

struct GroupCellView: View {
    let group: PresetGroup
    let isGroupHighlighted: Bool
    let activeZoneIndex: Int?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                ForEach(Array(group.rects.enumerated()), id: \.offset) { ri, rect in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(rectFill(ri))
                        .frame(width: rect.width * group.iconWidth,
                               height: rect.height * group.iconHeight)
                        .position(x: rect.midX * group.iconWidth,
                                  y: rect.midY * group.iconHeight)
                }
            }
            .frame(width: group.iconWidth, height: group.iconHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isGroupHighlighted ? Color.blue.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isGroupHighlighted ? Color.blue.opacity(0.06) : Color.clear)
            )

            // Label — fixed height must match SnapBarPanel.labelHeight
            Text(group.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isGroupHighlighted ? .primary : .secondary)
                .frame(height: SnapBarPanel.labelHeight)
        }
        .frame(width: group.iconWidth)  // match hit testing layout
        .scaleEffect(isGroupHighlighted ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isGroupHighlighted)
        .animation(.easeOut(duration: 0.1), value: activeZoneIndex)
    }

    private func rectFill(_ index: Int) -> Color {
        if let azi = activeZoneIndex {
            let zone = group.zones[azi]
            if index == zone.activeRectIndex {
                return .blue
            }
        }
        return Color.primary.opacity(isGroupHighlighted ? 0.12 : 0.08)
    }
}
