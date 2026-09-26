import Foundation

struct SyllabusAssignmentDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var dueDate: Date
    var isSelected: Bool

    init(id: UUID = UUID(), title: String, dueDate: Date, isSelected: Bool = true) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isSelected = isSelected
    }
}

struct SyllabusImportResult: Equatable, Sendable {
    var courseCode: String
    var courseName: String
    var drafts: [SyllabusAssignmentDraft]
    var warnings: [String]
}

struct SchoolEmailMessage: Equatable, Sendable {
    let id: String
    let subject: String
    let sender: String
    let body: String
}

struct EmailDeadlineSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let messageID: String
    let assignmentID: String
    let courseCode: String
    let assignmentTitle: String
    let previousDueDate: Date?
    let proposedDueDate: Date
    let emailSubject: String
    let sender: String
}
