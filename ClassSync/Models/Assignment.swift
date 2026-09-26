import Foundation

enum AssignmentStatus: String, Codable, CaseIterable, Sendable {
    case upcoming
    case submitted
    case overdue
    case unknown
}

enum AssignmentSource: String, Codable, CaseIterable, Sendable {
    case brightspace
    case brightspaceCalendar
    case syllabus
    case email
    case gradescope
    case crowdmark
    case manual

    var displayName: String {
        switch self {
        case .brightspace: "Brightspace"
        case .brightspaceCalendar: "Brightspace Calendar"
        case .syllabus: "Syllabus"
        case .email: "Email"
        case .gradescope: "Gradescope"
        case .crowdmark: "Crowdmark"
        case .manual: "Manual"
        }
    }
}

struct Assignment: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let externalID: String
    let courseID: String
    let courseName: String
    let courseCode: String
    let title: String
    let dueDate: Date?
    let source: AssignmentSource
    let url: URL?
    let status: AssignmentStatus
    let createdAt: Date
    let updatedAt: Date

    static func stableID(source: AssignmentSource, externalID: String) -> String {
        "\(source.rawValue):\(externalID)"
    }

    var isOverdue: Bool {
        guard status != .submitted, let dueDate else { return false }
        return status == .overdue || dueDate < Date()
    }

    static func dueDateAscending(_ lhs: Assignment, _ rhs: Assignment) -> Bool {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (left?, right?):
            if left == right { return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }
}
