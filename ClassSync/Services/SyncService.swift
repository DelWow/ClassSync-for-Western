import Foundation

enum SyncState: Equatable, Sendable {
    case idle
    case syncing
    case success(Date)
    case failed(String)
}

struct SyncResult: Equatable, Sendable {
    let courses: [Course]
    let assignments: [Assignment]
    let changes: [AssignmentChange]
    let completedAt: Date
}

@MainActor
final class SyncService {
    private(set) var state: SyncState = .idle

    private let provider: any AssignmentProvider
    private let store: any AssignmentStore
    private let changeDetector: ChangeDetector

    init(
        provider: any AssignmentProvider,
        store: any AssignmentStore,
        changeDetector: ChangeDetector = ChangeDetector()
    ) {
        self.provider = provider
        self.store = store
        self.changeDetector = changeDetector
    }

    func sync() async -> SyncResult? {
        guard state != .syncing else { return nil }

        state = .syncing
        let attemptedAt = Date()

        do {
            try store.updateSyncMetadata(providerID: provider.id, attemptedAt: attemptedAt, successfulAt: nil)
            let previous = try store.fetchAssignments()
            async let fetchedCourses = provider.fetchCourses()
            async let fetchedAssignments = provider.fetchAssignments()
            let (courses, assignments) = try await (fetchedCourses, fetchedAssignments)
            let sortedAssignments = assignments.sorted(by: Assignment.dueDateAscending)
            let changes = changeDetector.detect(previous: previous, current: sortedAssignments, detectedAt: attemptedAt)

            let completedAt = Date()
            try store.applySyncResult(
                courses: courses,
                assignments: sortedAssignments,
                changes: changes,
                providerID: provider.id,
                attemptedAt: attemptedAt,
                successfulAt: completedAt
            )
            state = .success(completedAt)
            return SyncResult(
                courses: courses,
                assignments: sortedAssignments,
                changes: changes,
                completedAt: completedAt
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Synchronization failed. Try again."
            AppLogger.sync.error("Sync failed with error type: \(String(describing: type(of: error)), privacy: .public)")
            state = .failed(message)
            return nil
        }
    }
}

@MainActor
final class InMemoryAssignmentStore: AssignmentStore {
    private(set) var courses: [Course]
    private(set) var assignments: [Assignment]
    private(set) var changes: [AssignmentChange]
    private var successfulSyncs: [String: Date] = [:]

    init(courses: [Course] = [], assignments: [Assignment] = [], changes: [AssignmentChange] = []) {
        self.courses = courses
        self.assignments = assignments
        self.changes = changes
    }

    func fetchCourses() throws -> [Course] { courses }
    func fetchAssignments() throws -> [Assignment] { assignments }
    func fetchChanges() throws -> [AssignmentChange] { changes }

    func saveCourses(_ courses: [Course]) throws {
        self.courses = courses
    }

    func replaceAssignments(with assignments: [Assignment]) throws {
        self.assignments = assignments
    }

    func saveChanges(_ changes: [AssignmentChange]) throws {
        let existingIDs = Set(self.changes.map(\.id))
        self.changes.append(contentsOf: changes.filter { !existingIDs.contains($0.id) })
    }

    func applySyncResult(
        courses: [Course],
        assignments: [Assignment],
        changes: [AssignmentChange],
        providerID: String,
        attemptedAt: Date,
        successfulAt: Date
    ) throws {
        try saveCourses(courses)
        try replaceAssignments(with: assignments)
        try saveChanges(changes)
        successfulSyncs[providerID] = successfulAt
    }

    func markChangeNotificationHandled(id: UUID) throws {
        guard let index = changes.firstIndex(where: { $0.id == id }) else { return }
        changes[index].notificationHandled = true
    }

    func lastSuccessfulSync(providerID: String) throws -> Date? {
        successfulSyncs[providerID]
    }

    func updateSyncMetadata(providerID: String, attemptedAt: Date, successfulAt: Date?) throws {
        if let successfulAt {
            successfulSyncs[providerID] = successfulAt
        }
    }

    func deleteAllData() throws {
        courses.removeAll()
        assignments.removeAll()
        changes.removeAll()
        successfulSyncs.removeAll()
    }
}
