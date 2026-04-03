import Foundation
import CoreGraphics

struct WindowFilter {
    private static let defaultExcludedRoles: Set<String> = [
        "AXDialog",
        "AXSheet",
    ]

    private static let defaultExcludedSubroles: Set<String> = [
        "AXDialog",
        "AXFloatingWindow",
        "AXSystemDialog",
    ]

    let excludedApps: [AppMatcher]
    let excludedRoles: Set<String>
    let excludedSubroles: Set<String>
    let minWidth: CGFloat
    let minHeight: CGFloat
    let excludeMinimized: Bool

    init(configuration: Configuration) {
        let config = configuration.windowFilter

        excludedApps = config?.excludedApps ?? []
        excludedRoles = Self.defaultExcludedRoles.union(config?.excludedRoles ?? [])
        excludedSubroles = Self.defaultExcludedSubroles.union(config?.excludedSubroles ?? [])
        minWidth = CGFloat(config?.minWidth ?? Constants.WindowFilter.minimumWidth)
        minHeight = CGFloat(config?.minHeight ?? Constants.WindowFilter.minimumHeight)
        excludeMinimized = config?.excludeMinimized ?? true
    }

    func allows(window: WindowManager.WindowInfo) -> Bool {
        allows(
            bundleId: window.bundleId,
            appName: window.appName,
            role: window.role,
            subrole: window.subrole,
            frame: window.frame,
            isMinimized: window.isMinimized
        )
    }

    func allows(snapshot: WindowSnapshot) -> Bool {
        allows(
            bundleId: snapshot.bundleId,
            appName: snapshot.appName,
            role: snapshot.windowRole,
            subrole: snapshot.windowSubrole,
            frame: snapshot.frame.cgRect,
            isMinimized: false
        )
    }

    private func allows(bundleId: String?, appName: String, role: String?, subrole: String?, frame: CGRect, isMinimized: Bool) -> Bool {
        if excludeMinimized && isMinimized {
            return false
        }

        if frame.width < minWidth || frame.height < minHeight {
            return false
        }

        if let role, excludedRoles.contains(role) {
            return false
        }

        if let subrole, excludedSubroles.contains(subrole) {
            return false
        }

        if excludedApps.contains(where: { $0.matches(bundleId: bundleId, appName: appName) }) {
            return false
        }

        return true
    }
}
