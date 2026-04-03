import Cocoa

/// AppKit 全局坐标（主屏左下原点）与 Accessibility 全局坐标（主屏左上原点）转换工具。
enum CoordinateConverter {
    static func mainScreenFrame(from screenFrames: [CGRect]) -> CGRect? {
        screenFrames.first(where: isMainScreenFrame) ?? screenFrames.first
    }

    static func nsToAccessibility(_ point: NSPoint, mainScreenFrame: CGRect) -> CGPoint {
        CGPoint(x: point.x, y: mainScreenFrame.maxY - point.y)
    }

    static func nsToAccessibility(_ frame: CGRect, mainScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: mainScreenFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func accessibilityToNS(_ point: CGPoint, mainScreenFrame: CGRect) -> NSPoint {
        NSPoint(x: point.x, y: mainScreenFrame.maxY - point.y)
    }

    static func accessibilityToNS(_ frame: CGRect, mainScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: mainScreenFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func accessibilityScreenFrame(for screen: ScreenInfo, screens: [ScreenInfo]) -> CGRect? {
        accessibilityScreenFrame(for: screen.frame, screenFrames: screens.map(\.frame))
    }

    static func accessibilityScreenFrame(for screenFrame: CGRect, screenFrames: [CGRect]) -> CGRect? {
        guard let mainScreenFrame = mainScreenFrame(from: screenFrames) else { return nil }
        return nsToAccessibility(screenFrame, mainScreenFrame: mainScreenFrame)
    }

    static func screenContainingAccessibilityPoint(_ point: CGPoint, in screens: [ScreenInfo]) -> ScreenInfo? {
        screens.first { screen in
            guard let frame = accessibilityScreenFrame(for: screen, screens: screens) else { return false }
            return frame.contains(point)
        }
    }

    static func containsAccessibilityPoint(_ point: CGPoint, in screen: ScreenInfo, screens: [ScreenInfo]) -> Bool {
        guard let frame = accessibilityScreenFrame(for: screen, screens: screens) else { return false }
        return frame.contains(point)
    }

    private static func isMainScreenFrame(_ frame: CGRect) -> Bool {
        abs(frame.origin.x) < 0.5 && abs(frame.origin.y) < 0.5
    }
}
