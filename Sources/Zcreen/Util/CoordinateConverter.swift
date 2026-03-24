import Cocoa

/// NS (左下原点) ↔ CG (左上原点) 坐标系转换工具
enum CoordinateConverter {
    /// 主屏幕高度 (坐标转换基准)
    static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// NS point → CG point
    static func nsToCG(_ point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    /// NS frame → CG frame
    static func nsToCG(_ frame: NSRect) -> CGRect {
        CGRect(
            x: frame.origin.x,
            y: primaryScreenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
    }

    /// CG point → NS point
    static func cgToNS(_ point: CGPoint) -> NSPoint {
        NSPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
}
