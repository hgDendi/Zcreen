import SwiftUI

@main
struct ScreenAnchorApp: App {
    @StateObject private var orchestrator = Orchestrator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(orchestrator: orchestrator)
        } label: {
            Image(systemName: "rectangle.3.group")
        }
        .menuBarExtraStyle(.window)
    }

    init() {
        // Prompt for accessibility permission on first launch
        if !AccessibilityHelper.isTrusted {
            AccessibilityHelper.requestAccess()
        }
    }
}
