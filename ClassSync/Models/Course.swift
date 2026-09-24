import Foundation

struct Course: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let externalID: String
    let code: String
    let name: String
    let source: AssignmentSource
    let isActive: Bool
    let colorHex: String?

    static func stableID(source: AssignmentSource, externalID: String) -> String {
        "\(source.rawValue):\(externalID)"
    }
}

