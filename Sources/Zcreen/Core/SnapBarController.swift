import Cocoa
import ApplicationServices

final class SnapBarController: ObservableObject {
    @Published var isEnabled = true

    /// Called after a preset is applied, so the layout can be saved
    var onSnap: (() -> Void)?

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

    private var edgeOverlay = EdgeSnapOverlay()
    private var activeEdgePreset: LayoutPreset?

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

        if mouseDown && !wasMouseDown {
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

        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              app.activationPolicy == .regular
        else {
            dragState = .idle
            return
        }

        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        guard let win = focusedWindow(of: appEl) ?? firstWindow(of: appEl) else {
            dragState = .idle
            return
        }

        targetWindow = win

        guard let wFrame = windowFrame(win) else { return }

        // Convert NS mouse → CG for comparison with AX window frame
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let mouseCG = CGPoint(x: mouse.x, y: primaryH - mouse.y)

        // Title bar = top ~50px of the window (in CG coords)
        let titleBar = CGRect(x: wFrame.origin.x - 5,
                              y: wFrame.origin.y - 5,
                              width: wFrame.width + 10,
                              height: 50)

        clickedTitleBar = titleBar.contains(mouseCG)
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

            // Edge snap: show preview when mouse is near screen edges/corners
            updateEdgeSnap(at: mouse)
        }
    }

    // MARK: - Mouse Up: apply preset if highlighted

    private func onMouseUp(_ mouse: NSPoint) {
        defer {
            dragState = .idle
            tickCount = 0
            initialMousePos = nil
            clickedTitleBar = false
            clearEdgeSnap()
        }

        guard dragState == .snapping else {
            hidePanel()
            return
        }

        if isShowing, let panel, let preset = panel.presetAt(mouse) {
            applyPreset(preset)
        } else if let edgePreset = activeEdgePreset {
            applyPreset(edgePreset)
        }
        hidePanel()
    }

    // MARK: - Panel management

    private func showPanel(on screen: NSScreen) {
        panel?.hide()  // hide old panel before creating new one
        let groups = PresetGroup.groups(for: screen)
        panel = SnapBarPanel(groups: groups)
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
        panel?.updateHighlight(at: mouse)
    }

    // MARK: - Apply preset

    private func applyPreset(_ preset: LayoutPreset) {
        guard let win = targetWindow, let screen = targetScreen else { return }

        // Convert NS visibleFrame (bottom-left origin) → CG coordinates (top-left origin)
        // AXUIElement uses CG coordinates
        let nsFrame = screen.visibleFrame
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        let cgVisible = CGRect(
            x: nsFrame.origin.x,
            y: primaryH - nsFrame.origin.y - nsFrame.height,
            width: nsFrame.width,
            height: nsFrame.height
        )

        let frame = preset.frame(for: cgVisible)
        windowManager.moveWindow(win, toFrame: frame)
        Log.general.info("Snapped '\(preset.id)' on \(screen.localizedName)")

        // Persist layout after a short delay (let the window settle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onSnap?()
        }
    }

    // MARK: - Edge Snap

    private func updateEdgeSnap(at mouse: NSPoint) {
        guard let screen = targetScreen ?? screenAt(mouse) else {
            clearEdgeSnap()
            return
        }

        // Only activate edge snap when the Snap Bar has no highlight
        let snapBarHighlighted = panel?.state.highlightedGroupIndex != nil
        if !snapBarHighlighted, let preset = detectEdgePreset(at: mouse, on: screen) {
            activeEdgePreset = preset
            edgeOverlay.show(preset: preset, on: screen)
        } else {
            clearEdgeSnap()
        }
    }

    private func clearEdgeSnap() {
        if activeEdgePreset != nil {
            activeEdgePreset = nil
            edgeOverlay.hide()
        }
    }

    private enum ScreenEdge { case left, right, top, bottom }

    /// Check if the given edge of the screen is a physical boundary (no adjacent monitor).
    private func isPhysicalEdge(_ edge: ScreenEdge, at mouse: NSPoint, on screen: NSScreen) -> Bool {
        let step: CGFloat = 2
        let frame = screen.frame
        let testPoint: NSPoint
        switch edge {
        case .left:   testPoint = NSPoint(x: frame.minX - step, y: mouse.y)
        case .right:  testPoint = NSPoint(x: frame.maxX + step, y: mouse.y)
        case .top:    testPoint = NSPoint(x: mouse.x, y: frame.maxY + step)
        case .bottom: testPoint = NSPoint(x: mouse.x, y: frame.minY - step)
        }
        return screenAt(testPoint) == nil
    }

    /// Detect which edge/corner preset the mouse is in, or nil if not near any edge.
    private func detectEdgePreset(at mouse: NSPoint, on screen: NSScreen) -> LayoutPreset? {
        let frame = screen.frame
        let e: CGFloat = 6    // pixels from edge to trigger
        let c: CGFloat = 150  // corner region size

        let dLeft   = mouse.x - frame.minX
        let dRight  = frame.maxX - mouse.x
        let dTop    = frame.maxY - mouse.y
        let dBottom = mouse.y - frame.minY

        let atLeft   = dLeft < e   && isPhysicalEdge(.left,   at: mouse, on: screen)
        let atRight  = dRight < e  && isPhysicalEdge(.right,  at: mouse, on: screen)
        let atTop    = dTop < e    && isPhysicalEdge(.top,    at: mouse, on: screen)
        let atBottom = dBottom < e && isPhysicalEdge(.bottom, at: mouse, on: screen)

        guard atLeft || atRight || atTop || atBottom else { return nil }

        // Corners first (more specific than edges)
        if (atTop && dLeft < c) || (atLeft && dTop < c) {
            return LayoutPreset(id: "edge-top-left", relX: 0, relY: 0, relW: 0.5, relH: 0.5)
        }
        if (atTop && dRight < c) || (atRight && dTop < c) {
            return LayoutPreset(id: "edge-top-right", relX: 0.5, relY: 0, relW: 0.5, relH: 0.5)
        }
        if (atBottom && dLeft < c) || (atLeft && dBottom < c) {
            return LayoutPreset(id: "edge-bottom-left", relX: 0, relY: 0.5, relW: 0.5, relH: 0.5)
        }
        if (atBottom && dRight < c) || (atRight && dBottom < c) {
            return LayoutPreset(id: "edge-bottom-right", relX: 0.5, relY: 0.5, relW: 0.5, relH: 0.5)
        }

        // Pure edges (top without corner → snap bar handles it)
        if atLeft  { return LayoutPreset(id: "edge-left-half",  relX: 0,   relY: 0, relW: 0.5, relH: 1) }
        if atRight { return LayoutPreset(id: "edge-right-half", relX: 0.5, relY: 0, relW: 0.5, relH: 1) }

        return nil
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
