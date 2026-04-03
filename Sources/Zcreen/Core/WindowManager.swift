import Cocoa
import ApplicationServices

class WindowManager {
    private let screenFramesProvider: () -> [CGRect]

    init(screenFramesProvider: @escaping () -> [CGRect] = { NSScreen.screens.map(\.frame) }) {
        self.screenFramesProvider = screenFramesProvider
    }

    struct WindowInfo {
        let pid: pid_t
        let bundleId: String?
        let appName: String
        let title: String?
        let role: String?
        let subrole: String?
        let isMinimized: Bool
        let frame: CGRect
        let axWindow: AXUIElement
    }

    func getAllWindows() -> [WindowInfo] {
        guard AccessibilityHelper.isTrusted else {
            Log.window.warning("Accessibility not trusted, cannot enumerate windows")
            return []
        }

        var result: [WindowInfo] = []
        let workspace = NSWorkspace.shared

        for app in workspace.runningApplications where app.activationPolicy == .regular {
            let pid = app.processIdentifier
            let bundleId = app.bundleIdentifier
            let appName = app.localizedName ?? "Unknown"

            let appElement = AXUIElementCreateApplication(pid)
            var windowsRef: CFTypeRef?
            let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
            guard err == .success, let windows = windowsRef as? [AXUIElement] else { continue }

            for window in windows {
                guard let frame = getWindowFrame(window) else { continue }
                let title = getWindowTitle(window)
                let role = getStringAttribute(window, attribute: kAXRoleAttribute as CFString)
                let subrole = getStringAttribute(window, attribute: kAXSubroleAttribute as CFString)
                let isMinimized = getBoolAttribute(window, attribute: kAXMinimizedAttribute as CFString) ?? false
                result.append(WindowInfo(
                    pid: pid,
                    bundleId: bundleId,
                    appName: appName,
                    title: title,
                    role: role,
                    subrole: subrole,
                    isMinimized: isMinimized,
                    frame: frame,
                    axWindow: window
                ))
            }
        }

        return result
    }

    func getWindows(bundleId: String) -> [WindowInfo] {
        guard AccessibilityHelper.isTrusted else { return [] }

        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else {
            return []
        }

        let pid = app.processIdentifier
        let appName = app.localizedName ?? "Unknown"
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard err == .success, let windows = windowsRef as? [AXUIElement] else { return [] }

        return windows.compactMap { window in
            guard let frame = getWindowFrame(window) else { return nil }
            let title = getWindowTitle(window)
            let role = getStringAttribute(window, attribute: kAXRoleAttribute as CFString)
            let subrole = getStringAttribute(window, attribute: kAXSubroleAttribute as CFString)
            let isMinimized = getBoolAttribute(window, attribute: kAXMinimizedAttribute as CFString) ?? false
            return WindowInfo(
                pid: pid,
                bundleId: bundleId,
                appName: appName,
                title: title,
                role: role,
                subrole: subrole,
                isMinimized: isMinimized,
                frame: frame,
                axWindow: window
            )
        }
    }

    func getAllWindows(filter: WindowFilter) -> [WindowInfo] {
        getAllWindows().filter(filter.allows(window:))
    }

    func getWindows(bundleId: String, filter: WindowFilter) -> [WindowInfo] {
        getWindows(bundleId: bundleId).filter(filter.allows(window:))
    }

    func moveWindow(_ window: AXUIElement, to point: CGPoint) {
        var position = point
        let positionValue = AXValueCreate(.cgPoint, &position)!
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
    }

    func resizeWindow(_ window: AXUIElement, to size: CGSize) {
        var sz = size
        let sizeValue = AXValueCreate(.cgSize, &sz)!
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    func moveWindow(_ window: AXUIElement, toFrame frame: CGRect) {
        moveWindow(window, to: frame.origin)
        resizeWindow(window, to: frame.size)
    }

    func moveWindowToScreen(_ window: AXUIElement, currentFrame: CGRect, targetScreen: ScreenInfo) {
        let screenFrames = screenFramesProvider()
        guard let mainScreenFrame = CoordinateConverter.mainScreenFrame(from: screenFrames),
              let targetFrame = CoordinateConverter.accessibilityScreenFrame(for: targetScreen.frame, screenFrames: screenFrames)
        else {
            moveWindow(window, toFrame: currentFrame)
            return
        }

        let currentCenter = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let sourceFrame = screenFrames.compactMap { screenFrame -> CGRect? in
            let accessibilityFrame = CoordinateConverter.nsToAccessibility(screenFrame, mainScreenFrame: mainScreenFrame)
            return accessibilityFrame.contains(currentCenter) ? accessibilityFrame : nil
        }.first ?? CoordinateConverter.nsToAccessibility(mainScreenFrame, mainScreenFrame: mainScreenFrame)

        // Calculate relative position (0..1)
        let relX = (currentFrame.origin.x - sourceFrame.origin.x) / sourceFrame.width
        let relY = (currentFrame.origin.y - sourceFrame.origin.y) / sourceFrame.height
        let relW = currentFrame.width / sourceFrame.width
        let relH = currentFrame.height / sourceFrame.height

        // Map to target screen
        let newX = targetFrame.origin.x + relX * targetFrame.width
        let newY = targetFrame.origin.y + relY * targetFrame.height
        let newW = min(relW * targetFrame.width, targetFrame.width)
        let newH = min(relH * targetFrame.height, targetFrame.height)

        let newFrame = CGRect(x: newX, y: newY, width: newW, height: newH)
        moveWindow(window, toFrame: newFrame)
        Log.window.info("Moved window to screen \(targetScreen.name) at \(newFrame.debugDescription)")
    }

    // MARK: - Private

    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionRef as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        return CGRect(origin: position, size: size)
    }

    private func getWindowTitle(_ window: AXUIElement) -> String? {
        getStringAttribute(window, attribute: kAXTitleAttribute as CFString)
    }

    private func getStringAttribute(_ window: AXUIElement, attribute: CFString) -> String? {
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute, &titleRef) == .success else {
            return nil
        }
        return titleRef as? String
    }

    private func getBoolAttribute(_ window: AXUIElement, attribute: CFString) -> Bool? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute, &valueRef) == .success else {
            return nil
        }
        return valueRef as? Bool
    }
}
