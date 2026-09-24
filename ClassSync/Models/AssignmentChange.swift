import Foundation

enum AssignmentChangeType: String, Codable, CaseIterable, Sendable {
    case dueDate
    case title
    case created
    case removed
    case submissionStatus
}

struct AssignmentChange: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let assignmentID: String
    let courseID: String
    let courseCode: String
    let assignmentTitle: String
    let changeType: AssignmentChangeType
    let oldValue: String?
    let newValue: String?
    let detectedAt: Date
    var notificationHandled: Bool
}

