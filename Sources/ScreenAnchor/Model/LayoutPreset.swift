import Foundation
import CoreGraphics
import Cocoa

struct LayoutPreset: Equatable {
    let id: String
    let relX: CGFloat
    let relY: CGFloat
    let relW: CGFloat
    let relH: CGFloat

    /// Gap in points between adjacent split windows
    private static let gap: CGFloat = 6

    func frame(for visibleFrame: CGRect) -> CGRect {
        var f = CGRect(
            x: visibleFrame.origin.x + relX * visibleFrame.width,
            y: visibleFrame.origin.y + relY * visibleFrame.height,
            width: relW * visibleFrame.width,
            height: relH * visibleFrame.height
        )
        let g = Self.gap / 2
        // Add gap on inner edges only (not on screen edges)
        if relX > 0.01 { f.origin.x += g; f.size.width -= g }
        if relX + relW < 0.99 { f.size.width -= g }
        if relY > 0.01 { f.origin.y += g; f.size.height -= g }
        if relY + relH < 0.99 { f.size.height -= g }
        return f
    }
}

struct PresetGroup: Identifiable {
    let id: String
    let label: String
    let iconWidth: CGFloat
    let iconHeight: CGFloat
    let rects: [CGRect]
    let zones: [Zone]

    struct Zone {
        let hitRect: CGRect
        let activeRectIndex: Int
        let preset: LayoutPreset
    }
}

// MARK: - Group definitions

extension PresetGroup {

    /// Create a copy with different icon dimensions (rects are normalized, so they scale)
    func sized(_ w: CGFloat, _ h: CGFloat) -> PresetGroup {
        PresetGroup(id: id, label: label, iconWidth: w, iconHeight: h, rects: rects, zones: zones)
    }

    static func groups(for screen: NSScreen) -> [PresetGroup] {
        let isPortrait = screen.frame.height > screen.frame.width

        if isPortrait {
            // Portrait icons: taller than wide to match screen shape
            let bw: CGFloat = 40, bh: CGFloat = 62
            let wide: CGFloat = 62
            return [
                full.sized(bw, bh),
                paddedFull.sized(bw, bh),
                halves.sized(wide, bh),
                halvesVertical.sized(bw, bh),
                thirdsVertical.sized(bw, bh),
                quarters.sized(wide, bh),
            ]
        } else {
            return [full, paddedFull, halves, thirds, quarters]
        }
    }

    // MARK: Full

    static let full = PresetGroup(
        id: "full", label: "Full",
        iconWidth: 68, iconHeight: 48,
        rects: [CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92)],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                 activeRectIndex: 0,
                 preset: LayoutPreset(id: "full", relX: 0, relY: 0, relW: 1, relH: 1))
        ]
    )

    // MARK: Padded Full (10% margin each side)

    static let paddedFull = PresetGroup(
        id: "padded", label: "Padded",
        iconWidth: 68, iconHeight: 48,
        rects: [
            CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.92),
            CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70),
        ],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                 activeRectIndex: 1,
                 preset: LayoutPreset(id: "padded-full", relX: 0.1, relY: 0.1, relW: 0.8, relH: 0.8))
        ]
    )

    // MARK: Horizontal Halves (landscape + portrait)

    static let halves = PresetGroup(
        id: "halves", label: "½",
        iconWidth: 96, iconHeight: 48,
        rects: [
            CGRect(x: 0.04, y: 0.04, width: 0.44, height: 0.92),
            CGRect(x: 0.52, y: 0.04, width: 0.44, height: 0.92),
        ],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 0.5, height: 1),
                 activeRectIndex: 0,
                 preset: LayoutPreset(id: "left-half", relX: 0, relY: 0, relW: 0.5, relH: 1)),
            Zone(hitRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1),
                 activeRectIndex: 1,
                 preset: LayoutPreset(id: "right-half", relX: 0.5, relY: 0, relW: 0.5, relH: 1)),
        ]
    )

    // MARK: Vertical Halves (portrait only)

    static let halvesVertical = PresetGroup(
        id: "halves-v", label: "½",
        iconWidth: 68, iconHeight: 48,
        rects: [
            CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.44),
            CGRect(x: 0.04, y: 0.52, width: 0.92, height: 0.44),
        ],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 1, height: 0.5),
                 activeRectIndex: 0,
                 preset: LayoutPreset(id: "top-half", relX: 0, relY: 0, relW: 1, relH: 0.5)),
            Zone(hitRect: CGRect(x: 0, y: 0.5, width: 1, height: 0.5),
                 activeRectIndex: 1,
                 preset: LayoutPreset(id: "bottom-half", relX: 0, relY: 0.5, relW: 1, relH: 0.5)),
        ]
    )

    // MARK: Horizontal Thirds (landscape)

    static let thirds = PresetGroup(
        id: "thirds", label: "⅓",
        iconWidth: 110, iconHeight: 48,
        rects: [
            CGRect(x: 0.03, y: 0.04, width: 0.29, height: 0.92),
            CGRect(x: 0.355, y: 0.04, width: 0.29, height: 0.92),
            CGRect(x: 0.68, y: 0.04, width: 0.29, height: 0.92),
        ],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 0.333, height: 1),
                 activeRectIndex: 0,
                 preset: LayoutPreset(id: "left-third", relX: 0, relY: 0, relW: 1/3, relH: 1)),
            Zone(hitRect: CGRect(x: 0.333, y: 0, width: 0.334, height: 1),
                 activeRectIndex: 1,
                 preset: LayoutPreset(id: "center-third", relX: 1/3, relY: 0, relW: 1/3, relH: 1)),
            Zone(hitRect: CGRect(x: 0.667, y: 0, width: 0.333, height: 1),
                 activeRectIndex: 2,
                 preset: LayoutPreset(id: "right-third", relX: 2/3, relY: 0, relW: 1/3, relH: 1)),
        ]
    )

    // MARK: Vertical Thirds (portrait)

    static let thirdsVertical = PresetGroup(
        id: "thirds-v", label: "⅓",
        iconWidth: 68, iconHeight: 48,
        rects: [
            CGRect(x: 0.04, y: 0.03, width: 0.92, height: 0.28),
            CGRect(x: 0.04, y: 0.355, width: 0.92, height: 0.28),
            CGRect(x: 0.04, y: 0.68, width: 0.92, height: 0.28),
        ],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 1, height: 0.333),
                 activeRectIndex: 0,
                 preset: LayoutPreset(id: "top-third", relX: 0, relY: 0, relW: 1, relH: 1/3)),
            Zone(hitRect: CGRect(x: 0, y: 0.333, width: 1, height: 0.334),
                 activeRectIndex: 1,
                 preset: LayoutPreset(id: "center-third-v", relX: 0, relY: 1/3, relW: 1, relH: 1/3)),
            Zone(hitRect: CGRect(x: 0, y: 0.667, width: 1, height: 0.333),
                 activeRectIndex: 2,
                 preset: LayoutPreset(id: "bottom-third", relX: 0, relY: 2/3, relW: 1, relH: 1/3)),
        ]
    )

    // MARK: Quarters

    static let quarters = PresetGroup(
        id: "quarters", label: "¼",
        iconWidth: 96, iconHeight: 48,
        rects: [
            CGRect(x: 0.04, y: 0.04, width: 0.44, height: 0.43),
            CGRect(x: 0.52, y: 0.04, width: 0.44, height: 0.43),
            CGRect(x: 0.04, y: 0.53, width: 0.44, height: 0.43),
            CGRect(x: 0.52, y: 0.53, width: 0.44, height: 0.43),
        ],
        zones: [
            Zone(hitRect: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                 activeRectIndex: 0,
                 preset: LayoutPreset(id: "top-left", relX: 0, relY: 0, relW: 0.5, relH: 0.5)),
            Zone(hitRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5),
                 activeRectIndex: 1,
                 preset: LayoutPreset(id: "top-right", relX: 0.5, relY: 0, relW: 0.5, relH: 0.5)),
            Zone(hitRect: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
                 activeRectIndex: 2,
                 preset: LayoutPreset(id: "bottom-left", relX: 0, relY: 0.5, relW: 0.5, relH: 0.5)),
            Zone(hitRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
                 activeRectIndex: 3,
                 preset: LayoutPreset(id: "bottom-right", relX: 0.5, relY: 0.5, relW: 0.5, relH: 0.5)),
        ]
    )
}
