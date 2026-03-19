import Foundation
import CoreGraphics

enum ScreenPosition: String, Codable {
    case leftmost
    case center
    case rightmost
    case single
}

struct ScreenInfo: Identifiable {
    let displayID: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isBuiltIn: Bool
    let position: ScreenPosition
    let vendorID: UInt32
    let modelID: UInt32
    let serialNumber: UInt32

    var id: CGDirectDisplayID { displayID }

    /// Stable hardware-based unique key for this physical display.
    /// Format: "vendorID-modelID-serialNumber"
    var uniqueKey: String {
        "\(vendorID)-\(modelID)-\(serialNumber)"
    }

    var shortName: String {
        if isBuiltIn { return "Built-in" }
        let parts = name.split(separator: " ")
        if parts.count > 1 {
            return String(parts.last!)
        }
        return name
    }

    var isPortrait: Bool {
        frame.height > frame.width
    }

    var orientationLabel: String {
        isPortrait ? "portrait" : "landscape"
    }
}
