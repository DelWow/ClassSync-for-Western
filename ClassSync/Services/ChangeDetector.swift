import Foundation

struct ChangeDetector: Sendable {
    private let calendar = Calendar(identifier: .gregorian)

    func detect(
        previous: [Assignment],
        current: [Assignment],
        detectedAt: Date = Date()
    ) -> [AssignmentChange] {
        let oldByID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        var changes: [AssignmentChange] = []

        for assignment in current {
            guard let old = oldByID[assignment.id] else {
                changes.append(change(for: assignment, type: .created, oldValue: nil, newValue: assignment.title, at: detectedAt))
                continue
            }

            if !datesRepresentSameInstant(old.dueDate, assignment.dueDate) {
                changes.append(
                    change(
                        for: assignment,
                        type: .dueDate,
                        oldValue: formatted(old.dueDate),
                        newValue: formatted(assignment.dueDate),
                        at: detectedAt
                    )
                )
            }

            if old.title != assignment.title {
                changes.append(change(for: assignment, type: .title, oldValue: old.title, newValue: assignment.title, at: detectedAt))
            }

            if old.status != assignment.status {
                changes.append(
                    change(
                        for: assignment,
                        type: .submissionStatus,
                        oldValue: old.status.rawValue,
                        newValue: assignment.status.rawValue,
                        at: detectedAt
                    )
                )
            }
        }

        for removed in previous where newByID[removed.id] == nil {
            changes.append(change(for: removed, type: .removed, oldValue: removed.title, newValue: nil, at: detectedAt))
        }

        return changes.sorted { $0.detectedAt > $1.detectedAt }
    }

    private func datesRepresentSameInstant(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case let (left?, right?):
            calendar.compare(left, to: right, toGranularity: .second) == .orderedSame
        case (nil, nil):
            true
        default:
            false
        }
    }

    private func formatted(_ date: Date?) -> String? {
        date?.formatted(date: .abbreviated, time: .shortened)
    }

    private func change(
        for assignment: Assignment,
        type: AssignmentChangeType,
        oldValue: String?,
        newValue: String?,
        at date: Date
    ) -> AssignmentChange {
        AssignmentChange(
            id: UUID(),
            assignmentID: assignment.id,
            courseID: assignment.courseID,
            courseCode: assignment.courseCode,
            assignmentTitle: assignment.title,
            changeType: type,
            oldValue: oldValue,
            newValue: newValue,
            detectedAt: date,
            notificationHandled: false
        )
    }
}
