import Cocoa
import ApplicationServices

final class SnapBarController: ObservableObject {
    @Published var isEnabled = true

    private let windowManager: WindowManager
    private var panel: SnapBarPanel?
    private var isShowing = false
    private var targetWindow: AXUIElement?
    private var targetScreen: NSScreen?

    private var pollTimer: Timer?

    private enum DragState { case idle, tracking, snapping }
    private var dragState: DragState = .idle
    private var tickCount = 0
    private var initialMousePos: NSPoint?
    private var clickedTitleBar = false
    private var wasMouseDown = false

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        startPolling()
    }

    deinit { pollTimer?.invalidate() }

    // MARK: - Polling (20 Hz, .common mode so it fires during window drags)

    private func startPolling() {
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func tick() {
        guard isEnabled else { return }
        guard AccessibilityHelper.isTrusted else {
            // Print once per second so user can check Console
            tickCount += 1
            if tickCount % 20 == 0 {
                Log.general.warning("Snap Bar: accessibility NOT trusted, tick \(self.tickCount)")
            }
            return
        }

        let mouseDown = (NSEvent.pressedMouseButtons & 1) != 0
        let mouse = NSEvent.mouseLocation

        // Heartbeat every 2s
        tickCount += 1
        if tickCount % 40 == 0 {
            Log.general.info("SNAP heartbeat \(self.tickCount) mouseDown=\(mouseDown) enabled=\(self.isEnabled)")
        }

        if mouseDown && !wasMouseDown {
            Log.general.info("SNAP: mouse pressed at \(Int(mouse.x)),\(Int(mouse.y))")
            onMouseDown(mouse)
        } else if mouseDown && wasMouseDown {
            onDragTick(mouse)
        } else if !mouseDown && wasMouseDown {
            onMouseUp(mouse)
        }

        wasMouseDown = mouseDown
    }

    // MARK: - Mouse Down: check if click is in a window's title bar

    private func onMouseDown(_ mouse: NSPoint) {
        dragState = .tracking
        tickCount = 0
        initialMousePos = mouse
        clickedTitleBar = false
        targetWindow = nil

        guard let app = NSWorkspace.shared.frontmostApplication else {
            Log.general.info("SNAP: no frontmost app")
            dragState = .idle
            return
        }

        let bid = app.bundleIdentifier ?? "?"
        let policy = app.activationPolicy.rawValue

        if bid == Bundle.main.bundleIdentifier {
            dragState = .idle
            return
        }

        if app.activationPolicy != .regular {
            Log.general.info("SNAP: skip \(bid) policy=\(policy)")
            dragState = .idle
            return
        }

        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        let win = focusedWindow(of: appEl) ?? firstWindow(of: appEl)

        guard let win else {
            Log.general.info("SNAP: no window for \(bid)")
            dragState = .idle
            return
        }

        targetWindow = win

        guard let wFrame = windowFrame(win) else {
            Log.general.info("SNAP: can't get frame for \(bid)")
            return
        }

        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let mouseCG = CGPoint(x: mouse.x, y: primaryH - mouse.y)

        let titleBar = CGRect(x: wFrame.origin.x - 5,
                              y: wFrame.origin.y - 5,
                              width: wFrame.width + 10,
                              height: 50)

        clickedTitleBar = titleBar.contains(mouseCG)
        Log.general.info("SNAP mouseDown: app=\(bid) wFrame=\(Int(wFrame.origin.x)),\(Int(wFrame.origin.y)),\(Int(wFrame.width))x\(Int(wFrame.height)) mouseCG=\(Int(mouseCG.x)),\(Int(mouseCG.y)) titleBar=\(self.clickedTitleBar)")
    }

    // MARK: - Drag tick: detect significant mouse movement from title bar

    private func onDragTick(_ mouse: NSPoint) {
        switch dragState {
        case .idle:
            return

        case .tracking:
            tickCount += 1

            // Need title bar click + significant mouse movement
            guard clickedTitleBar, let initial = initialMousePos else {
                if tickCount >= 20 { dragState = .idle }  // timeout ~1s
                return
            }

            let moved = hypot(mouse.x - initial.x, mouse.y - initial.y)
            if moved > 12 {
                // Window is being dragged → show snap bar
                dragState = .snapping
                let screen = screenAt(mouse) ?? NSScreen.main!
                showPanel(on: screen)
                updateHighlight(at: mouse)
            }

        case .snapping:
            updateHighlight(at: mouse)

            // Follow mouse across screens
            if let cur = targetScreen,
               let next = screenAt(mouse),
               next != cur {
                showPanel(on: next)
            }
        }
    }

    // MARK: - Mouse Up: apply preset if highlighted

    private func onMouseUp(_ mouse: NSPoint) {
        defer {
            dragState = .idle
            tickCount = 0
            initialMousePos = nil
            clickedTitleBar = false
        }

        guard dragState == .snapping, isShowing, let panel else { return }

        if let idx = panel.presetIndex(at: mouse) {
            applyPreset(panel.state.presets[idx])
        }
        hidePanel()
    }

    // MARK: - Panel management

    private func showPanel(on screen: NSScreen) {
        if panel == nil { panel = SnapBarPanel() }
        panel?.show(on: screen)
        targetScreen = screen
        isShowing = true
    }

    private func hidePanel() {
        panel?.hide()
        isShowing = false
        targetScreen = nil
    }

    private func updateHighlight(at mouse: NSPoint) {
        panel?.state.highlightedIndex = panel?.presetIndex(at: mouse)
    }

    // MARK: - Apply preset

    private func applyPreset(_ preset: LayoutPreset) {
        guard let win = targetWindow, let screen = targetScreen else { return }
        let frame = preset.frame(for: screen.visibleFrame)
        windowManager.moveWindow(win, toFrame: frame)
        Log.general.info("Snapped '\(preset.name)' on \(screen.localizedName)")
    }

    // MARK: - AX helpers

    private func focusedWindow(of app: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref) == .success
        else { return nil }
        return (ref as! AXUIElement)
    }

    private func firstWindow(of app: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &ref) == .success,
              let wins = ref as? [AXUIElement], let first = wins.first
        else { return nil }
        return first
    }

    private func windowFrame(_ win: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success
        else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: pos, size: size)
    }

    private func screenAt(_ point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }
}
