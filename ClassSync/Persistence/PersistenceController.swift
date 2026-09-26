import Foundation
import SwiftData

@Model
final class PersistentCourse {
    @Attribute(.unique) var id: String
    var externalID: String
    var code: String
    var name: String
    var sourceRawValue: String
    var isActive: Bool
    var colorHex: String?

    init(course: Course) {
        id = course.id
        externalID = course.externalID
        code = course.code
        name = course.name
        sourceRawValue = course.source.rawValue
        isActive = course.isActive
        colorHex = course.colorHex
    }

    func update(with course: Course) {
        externalID = course.externalID
        code = course.code
        name = course.name
        sourceRawValue = course.source.rawValue
        isActive = course.isActive
        colorHex = course.colorHex
    }

    var domainModel: Course {
        Course(
            id: id,
            externalID: externalID,
            code: code,
            name: name,
            source: AssignmentSource(rawValue: sourceRawValue) ?? .manual,
            isActive: isActive,
            colorHex: colorHex
        )
    }
}

@Model
final class PersistentAssignment {
    @Attribute(.unique) var id: String
    var externalID: String
    var courseID: String
    var courseName: String
    var courseCode: String
    var title: String
    var dueDate: Date?
    var sourceRawValue: String
    var urlString: String?
    var statusRawValue: String
    var createdAt: Date
    var updatedAt: Date

    init(assignment: Assignment) {
        id = assignment.id
        externalID = assignment.externalID
        courseID = assignment.courseID
        courseName = assignment.courseName
        courseCode = assignment.courseCode
        title = assignment.title
        dueDate = assignment.dueDate
        sourceRawValue = assignment.source.rawValue
        urlString = assignment.url?.absoluteString
        statusRawValue = assignment.status.rawValue
        createdAt = assignment.createdAt
        updatedAt = assignment.updatedAt
    }

    func update(with assignment: Assignment) {
        externalID = assignment.externalID
        courseID = assignment.courseID
        courseName = assignment.courseName
        courseCode = assignment.courseCode
        title = assignment.title
        dueDate = assignment.dueDate
        sourceRawValue = assignment.source.rawValue
        urlString = assignment.url?.absoluteString
        statusRawValue = assignment.status.rawValue
        createdAt = assignment.createdAt
        updatedAt = assignment.updatedAt
    }

    var domainModel: Assignment {
        Assignment(
            id: id,
            externalID: externalID,
            courseID: courseID,
            courseName: courseName,
            courseCode: courseCode,
            title: title,
            dueDate: dueDate,
            source: AssignmentSource(rawValue: sourceRawValue) ?? .manual,
            url: urlString.flatMap(URL.init(string:)),
            status: AssignmentStatus(rawValue: statusRawValue) ?? .unknown,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class PersistentAssignmentChange {
    @Attribute(.unique) var id: UUID
    var assignmentID: String
    var courseID: String
    var courseCode: String
    var assignmentTitle: String
    var changeTypeRawValue: String
    var oldValue: String?
    var newValue: String?
    var detectedAt: Date
    var notificationHandled: Bool

    init(change: AssignmentChange) {
        id = change.id
        assignmentID = change.assignmentID
        courseID = change.courseID
        courseCode = change.courseCode
        assignmentTitle = change.assignmentTitle
        changeTypeRawValue = change.changeType.rawValue
        oldValue = change.oldValue
        newValue = change.newValue
        detectedAt = change.detectedAt
        notificationHandled = change.notificationHandled
    }

    var domainModel: AssignmentChange {
        AssignmentChange(
            id: id,
            assignmentID: assignmentID,
            courseID: courseID,
            courseCode: courseCode,
            assignmentTitle: assignmentTitle,
            changeType: AssignmentChangeType(rawValue: changeTypeRawValue) ?? .title,
            oldValue: oldValue,
            newValue: newValue,
            detectedAt: detectedAt,
            notificationHandled: notificationHandled
        )
    }
}

@Model
final class PersistentSyncMetadata {
    @Attribute(.unique) var providerID: String
    var lastAttemptedAt: Date?
    var lastSuccessfulAt: Date?

    init(providerID: String, lastAttemptedAt: Date? = nil, lastSuccessfulAt: Date? = nil) {
        self.providerID = providerID
        self.lastAttemptedAt = lastAttemptedAt
        self.lastSuccessfulAt = lastSuccessfulAt
    }
}

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer
    let isUsingInMemoryFallback: Bool

    init(inMemory: Bool = false) {
        do {
            container = try Self.makeContainer(inMemory: inMemory)
            isUsingInMemoryFallback = false
        } catch {
            do {
                container = try Self.makeContainer(inMemory: true)
                isUsingInMemoryFallback = true
            } catch {
                fatalError("Unable to initialize SwiftData: \(error.localizedDescription)")
            }
        }
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema([
            PersistentCourse.self,
            PersistentAssignment.self,
            PersistentAssignmentChange.self,
            PersistentSyncMetadata.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
protocol AssignmentStore: AnyObject {
    func fetchCourses() throws -> [Course]
    func fetchAssignments() throws -> [Assignment]
    func fetchChanges() throws -> [AssignmentChange]
    func saveCourses(_ courses: [Course]) throws
    func replaceCourses(with courses: [Course]) throws
    func replaceAssignments(with assignments: [Assignment]) throws
    func saveChanges(_ changes: [AssignmentChange]) throws
    func applySyncResult(
        courses: [Course],
        assignments: [Assignment],
        changes: [AssignmentChange],
        providerID: String,
        attemptedAt: Date,
        successfulAt: Date
    ) throws
    func markChangeNotificationHandled(id: UUID) throws
    func lastSuccessfulSync(providerID: String) throws -> Date?
    func updateSyncMetadata(providerID: String, attemptedAt: Date, successfulAt: Date?) throws
    func deleteAllData() throws
}

@MainActor
final class SwiftDataAssignmentStore: AssignmentStore {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = container.mainContext
        context.autosaveEnabled = true
    }

    func fetchCourses() throws -> [Course] {
        try context.fetch(FetchDescriptor<PersistentCourse>())
            .map(\.domainModel)
            .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    func fetchAssignments() throws -> [Assignment] {
        try context.fetch(FetchDescriptor<PersistentAssignment>())
            .map(\.domainModel)
            .sorted(by: Assignment.dueDateAscending)
    }

    func fetchChanges() throws -> [AssignmentChange] {
        try context.fetch(FetchDescriptor<PersistentAssignmentChange>())
            .map(\.domainModel)
            .sorted { $0.detectedAt > $1.detectedAt }
    }

    func saveCourses(_ courses: [Course]) throws {
        try upsertCourses(courses)
        try context.save()
    }

    func replaceCourses(with courses: [Course]) throws {
        try replaceCourseModels(with: courses)
        try context.save()
    }

    func replaceAssignments(with assignments: [Assignment]) throws {
        try replaceAssignmentModels(with: assignments)
        try context.save()
    }

    func saveChanges(_ changes: [AssignmentChange]) throws {
        try insertChangesAndApplyRetention(changes)
        try context.save()
    }

    func applySyncResult(
        courses: [Course],
        assignments: [Assignment],
        changes: [AssignmentChange],
        providerID: String,
        attemptedAt: Date,
        successfulAt: Date
    ) throws {
        do {
            try replaceCourseModels(with: courses)
            try replaceAssignmentModels(with: assignments)
            try insertChangesAndApplyRetention(changes)
            let stored = try metadata(providerID: providerID) ?? {
                let value = PersistentSyncMetadata(providerID: providerID)
                context.insert(value)
                return value
            }()
            stored.lastAttemptedAt = attemptedAt
            stored.lastSuccessfulAt = successfulAt
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func upsertCourses(_ courses: [Course]) throws {
        let existing = try context.fetch(FetchDescriptor<PersistentCourse>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for course in courses {
            if let stored = byID[course.id] {
                stored.update(with: course)
            } else {
                context.insert(PersistentCourse(course: course))
            }
        }
    }

    private func replaceCourseModels(with courses: [Course]) throws {
        let existing = try context.fetch(FetchDescriptor<PersistentCourse>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let currentIDs = Set(courses.map(\.id))

        for course in courses {
            if let stored = byID[course.id] {
                stored.update(with: course)
            } else {
                context.insert(PersistentCourse(course: course))
            }
        }
        for stored in existing where !currentIDs.contains(stored.id) {
            context.delete(stored)
        }
    }

    private func replaceAssignmentModels(with assignments: [Assignment]) throws {
        let existing = try context.fetch(FetchDescriptor<PersistentAssignment>())
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let currentIDs = Set(assignments.map(\.id))

        for assignment in assignments {
            if let stored = byID[assignment.id] {
                stored.update(with: assignment)
            } else {
                context.insert(PersistentAssignment(assignment: assignment))
            }
        }

        for stored in existing where !currentIDs.contains(stored.id) {
            context.delete(stored)
        }
    }

    private func insertChangesAndApplyRetention(_ changes: [AssignmentChange]) throws {
        let existing = try context.fetch(FetchDescriptor<PersistentAssignmentChange>())
        let existingIDs = Set(existing.map(\.id))
        for change in changes where !existingIDs.contains(change.id) {
            context.insert(PersistentAssignmentChange(change: change))
        }

        // Keep one year of history, capped at the most recent 1,000 records.
        let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? .distantPast
        let retained = try context.fetch(FetchDescriptor<PersistentAssignmentChange>())
            .sorted { $0.detectedAt > $1.detectedAt }
        for change in retained.dropFirst(1_000) {
            context.delete(change)
        }
        for change in retained where change.detectedAt < cutoff {
            context.delete(change)
        }
    }

    func markChangeNotificationHandled(id: UUID) throws {
        guard let change = try context.fetch(FetchDescriptor<PersistentAssignmentChange>())
            .first(where: { $0.id == id }) else { return }
        change.notificationHandled = true
        try context.save()
    }

    func lastSuccessfulSync(providerID: String) throws -> Date? {
        try metadata(providerID: providerID)?.lastSuccessfulAt
    }

    func updateSyncMetadata(providerID: String, attemptedAt: Date, successfulAt: Date?) throws {
        let stored = try metadata(providerID: providerID) ?? {
            let value = PersistentSyncMetadata(providerID: providerID)
            context.insert(value)
            return value
        }()
        stored.lastAttemptedAt = attemptedAt
        if let successfulAt {
            stored.lastSuccessfulAt = successfulAt
        }
        try context.save()
    }

    func deleteAllData() throws {
        do {
            for value in try context.fetch(FetchDescriptor<PersistentAssignmentChange>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<PersistentAssignment>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<PersistentCourse>()) { context.delete(value) }
            for value in try context.fetch(FetchDescriptor<PersistentSyncMetadata>()) { context.delete(value) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func metadata(providerID: String) throws -> PersistentSyncMetadata? {
        try context.fetch(FetchDescriptor<PersistentSyncMetadata>())
            .first { $0.providerID == providerID }
    }
}
