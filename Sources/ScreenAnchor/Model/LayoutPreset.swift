import Foundation
import CoreGraphics

struct LayoutPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let group: Int

    /// Normalized zones for the visual icon (each rect in 0..1 space)
    let zones: [CGRect]
    /// Which zone is the "active" one (highlighted in the icon)
    let activeZone: Int

    /// Relative frame for window placement (x, y, w, h each in 0..1 of screen visible frame)
    let relX: CGFloat
    let relY: CGFloat
    let relW: CGFloat
    let relH: CGFloat

    func frame(for visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.origin.x + relX * visibleFrame.width,
            y: visibleFrame.origin.y + relY * visibleFrame.height,
            width: relW * visibleFrame.width,
            height: relH * visibleFrame.height
        )
    }

    static func == (lhs: LayoutPreset, rhs: LayoutPreset) -> Bool {
        lhs.id == rhs.id
    }
}

extension LayoutPreset {
    // Zone helpers
    private static let full1   = [CGRect(x: 0, y: 0, width: 1, height: 1)]
    private static let half2   = [CGRect(x: 0, y: 0, width: 0.48, height: 1),
                                  CGRect(x: 0.52, y: 0, width: 0.48, height: 1)]
    private static let third3  = [CGRect(x: 0, y: 0, width: 0.31, height: 1),
                                  CGRect(x: 0.345, y: 0, width: 0.31, height: 1),
                                  CGRect(x: 0.69, y: 0, width: 0.31, height: 1)]
    private static let twoOne  = [CGRect(x: 0, y: 0, width: 0.64, height: 1),
                                  CGRect(x: 0.68, y: 0, width: 0.32, height: 1)]
    private static let oneTwo  = [CGRect(x: 0, y: 0, width: 0.32, height: 1),
                                  CGRect(x: 0.36, y: 0, width: 0.64, height: 1)]
    private static let quad4   = [CGRect(x: 0, y: 0, width: 0.48, height: 0.47),
                                  CGRect(x: 0.52, y: 0, width: 0.48, height: 0.47),
                                  CGRect(x: 0, y: 0.53, width: 0.48, height: 0.47),
                                  CGRect(x: 0.52, y: 0.53, width: 0.48, height: 0.47)]

    static let all: [LayoutPreset] = [
        // Group 0: Full
        LayoutPreset(id: "full", name: "Full", group: 0,
                     zones: full1, activeZone: 0,
                     relX: 0, relY: 0, relW: 1, relH: 1),

        // Group 1: Halves
        LayoutPreset(id: "left-half", name: "Left ½", group: 1,
                     zones: half2, activeZone: 0,
                     relX: 0, relY: 0, relW: 0.5, relH: 1),
        LayoutPreset(id: "right-half", name: "Right ½", group: 1,
                     zones: half2, activeZone: 1,
                     relX: 0.5, relY: 0, relW: 0.5, relH: 1),

        // Group 2: Two-thirds
        LayoutPreset(id: "left-2-3", name: "Left ⅔", group: 2,
                     zones: twoOne, activeZone: 0,
                     relX: 0, relY: 0, relW: 2.0/3.0, relH: 1),
        LayoutPreset(id: "right-2-3", name: "Right ⅔", group: 2,
                     zones: oneTwo, activeZone: 1,
                     relX: 1.0/3.0, relY: 0, relW: 2.0/3.0, relH: 1),

        // Group 3: Thirds
        LayoutPreset(id: "left-third", name: "Left ⅓", group: 3,
                     zones: third3, activeZone: 0,
                     relX: 0, relY: 0, relW: 1.0/3.0, relH: 1),
        LayoutPreset(id: "center-third", name: "Center ⅓", group: 3,
                     zones: third3, activeZone: 1,
                     relX: 1.0/3.0, relY: 0, relW: 1.0/3.0, relH: 1),
        LayoutPreset(id: "right-third", name: "Right ⅓", group: 3,
                     zones: third3, activeZone: 2,
                     relX: 2.0/3.0, relY: 0, relW: 1.0/3.0, relH: 1),

        // Group 4: Quarters
        LayoutPreset(id: "top-left", name: "Top Left", group: 4,
                     zones: quad4, activeZone: 0,
                     relX: 0, relY: 0, relW: 0.5, relH: 0.5),
        LayoutPreset(id: "top-right", name: "Top Right", group: 4,
                     zones: quad4, activeZone: 1,
                     relX: 0.5, relY: 0, relW: 0.5, relH: 0.5),
        LayoutPreset(id: "bottom-left", name: "Bottom Left", group: 4,
                     zones: quad4, activeZone: 2,
                     relX: 0, relY: 0.5, relW: 0.5, relH: 0.5),
        LayoutPreset(id: "bottom-right", name: "Bottom Right", group: 4,
                     zones: quad4, activeZone: 3,
                     relX: 0.5, relY: 0.5, relW: 0.5, relH: 0.5),
    ]

    static let groupCount = 5
}
