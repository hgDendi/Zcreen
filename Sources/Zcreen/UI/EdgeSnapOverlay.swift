import Cocoa
import SwiftUI

/// Translucent overlay that previews where a window will snap when dragged to a screen edge or corner.
final class EdgeSnapOverlay {
    private var panel: NSPanel?
    private(set) var currentPreset: LayoutPreset?

    func show(preset: LayoutPreset, on screen: NSScreen) {
        // Same preset already showing — skip
        if preset == currentPreset, panel != nil { return }

        panel?.orderOut(nil)
        panel = nil
        currentPreset = preset

        // Convert preset relative frame → NS screen coordinates
        let nsVisible = screen.visibleFrame
        let primaryH = NSScreen.screens.first?.frame.height ?? 0

        // LayoutPreset.frame() expects CG coordinates (top-left origin)
        let cgVisible = CGRect(
            x: nsVisible.origin.x,
            y: primaryH - nsVisible.origin.y - nsVisible.height,
            width: nsVisible.width,
            height: nsVisible.height
        )
        let cgFrame = preset.frame(for: cgVisible)

        // CG → NS (bottom-left origin)
        let nsFrame = NSRect(
            x: cgFrame.origin.x,
            y: primaryH - cgFrame.origin.y - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )

        let p = NSPanel(
            contentRect: nsFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isMovableByWindowBackground = false
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: EdgeSnapPreviewView())
        hostingView.frame = NSRect(origin: .zero, size: nsFrame.size)
        p.contentView = hostingView

        p.alphaValue = 0
        p.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            p.animator().alphaValue = 1
        }

        panel = p
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        currentPreset = nil
    }
}

private struct EdgeSnapPreviewView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.blue.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.blue.opacity(0.4), lineWidth: 2)
            )
            .padding(4)
    }
}
