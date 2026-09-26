import Foundation

struct SourceReconciler: Sendable {
    func assignments(_ assignments: [Assignment]) -> [Assignment] {
        var selected: [String: Assignment] = [:]
        for assignment in assignments {
            let key = "\(normalized(assignment.courseCode))|\(normalized(assignment.title))"
            guard let current = selected[key] else {
                selected[key] = assignment
                continue
            }
            if assignment.source.displayPriority > current.source.displayPriority
                || (assignment.source.displayPriority == current.source.displayPriority && assignment.updatedAt > current.updatedAt) {
                selected[key] = assignment
            }
        }
        return selected.values.sorted(by: Assignment.dueDateAscending)
    }

    func courses(_ courses: [Course]) -> [Course] {
        var selected: [String: Course] = [:]
        for course in courses {
            let key = normalized(course.code)
            guard let current = selected[key] else {
                selected[key] = course
                continue
            }
            if course.source.displayPriority > current.source.displayPriority {
                selected[key] = course
            }
        }
        return selected.values.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
    }
}

private extension AssignmentSource {
    var displayPriority: Int {
        switch self {
        case .brightspace: 60
        case .brightspaceCalendar: 50
        case .email: 40
        case .syllabus: 30
        case .gradescope, .crowdmark: 20
        case .manual: 10
        }
    }
}
