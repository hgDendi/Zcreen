import Foundation
import CoreGraphics

struct WindowSnapshot: Codable, Equatable {
    let bundleId: String
    let appName: String
    let windowTitle: String?
    let frame: CodableRect
    let screenName: String
    let screenKey: String?
    let relativeFrame: CodableRect?
    let windowRole: String?
    let windowSubrole: String?

    init(bundleId: String, appName: String, windowTitle: String?, frame: CodableRect,
         screenName: String, screenKey: String? = nil, relativeFrame: CodableRect? = nil,
         windowRole: String? = nil, windowSubrole: String? = nil) {
        self.bundleId = bundleId
        self.appName = appName
        self.windowTitle = windowTitle
        self.frame = frame
        self.screenName = screenName
        self.screenKey = screenKey
        self.relativeFrame = relativeFrame
        self.windowRole = windowRole
        self.windowSubrole = windowSubrole
    }

    func resolvedFrame(using screens: [ScreenInfo]) -> CGRect {
        guard let screenKey,
              let relativeFrame,
              let screen = screens.first(where: { $0.uniqueKey == screenKey }),
              let screenFrame = CoordinateConverter.accessibilityScreenFrame(for: screen, screens: screens)
        else {
            return frame.cgRect
        }

        return relativeFrame.cgRect(in: screenFrame)
    }

    struct CodableRect: Codable, Equatable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double

        init(x: Double, y: Double, width: Double, height: Double) {
            self.x = x
            self.y = y
            self.width = width
            self.height = height
        }

        init(_ rect: CGRect) {
            self.x = rect.origin.x
            self.y = rect.origin.y
            self.width = rect.size.width
            self.height = rect.size.height
        }

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }

        func cgRect(in container: CGRect) -> CGRect {
            let clampedX = min(max(x, 0), 1)
            let clampedY = min(max(y, 0), 1)
            let clampedWidth = min(max(width, 0), 1)
            let clampedHeight = min(max(height, 0), 1)
            let originX = container.origin.x + clampedX * container.width
            let originY = container.origin.y + clampedY * container.height
            let availableWidth = max(container.maxX - originX, 0)
            let availableHeight = max(container.maxY - originY, 0)

            return CGRect(
                x: originX,
                y: originY,
                width: min(clampedWidth * container.width, availableWidth),
                height: min(clampedHeight * container.height, availableHeight)
            )
        }

        static func relative(from rect: CGRect, in container: CGRect) -> CodableRect {
            guard container.width > 0, container.height > 0 else {
                return CodableRect(x: 0, y: 0, width: 1, height: 1)
            }

            return CodableRect(
                x: (rect.origin.x - container.origin.x) / container.width,
                y: (rect.origin.y - container.origin.y) / container.height,
                width: rect.width / container.width,
                height: rect.height / container.height
            )
        }
    }
}
