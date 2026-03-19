import Foundation

struct LayoutSnapshot: Codable {
    let profileKey: String
    let profileLabel: String
    let timestamp: Date
    let windows: [WindowSnapshot]
}
