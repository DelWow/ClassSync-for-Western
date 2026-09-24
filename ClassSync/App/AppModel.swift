import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var courses: [Course] = []
    @Published private(set) var assignments: [Assignment] = []
    @Published private(set) var changes: [AssignmentChange] = []
    @Published private(set) var syncState: SyncState = .idle
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var persistenceMessage: String?

    private let providerID: String
    private let store: any AssignmentStore
    private let syncService: SyncService
    private var hasLoaded = false

    init(provider: any AssignmentProvider, store: any AssignmentStore) {
        providerID = provider.id
        self.store = store
        syncService = SyncService(provider: provider, store: store)
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        do {
            courses = try store.fetchCourses()
            assignments = try store.fetchAssignments()
            changes = try store.fetchChanges()
            lastSyncedAt = try store.lastSuccessfulSync(providerID: providerID)

            if courses.isEmpty && assignments.isEmpty {
                try store.saveCourses(MockData.courses)
                try store.replaceAssignments(with: MockData.assignments)
                courses = MockData.courses
                assignments = MockData.assignments
            }
        } catch {
            AppLogger.database.error("Local data load failed; using session-only mock data")
            persistenceMessage = "Local data could not be loaded. Mock data is shown for this session."
            courses = MockData.courses
            assignments = MockData.assignments
        }
    }

    func syncNow() async {
        guard syncState != .syncing else { return }
        syncState = .syncing

        if let result = await syncService.sync() {
            courses = result.courses
            assignments = result.assignments
            changes = (result.changes + changes)
                .uniqued(on: \.id)
                .sorted { $0.detectedAt > $1.detectedAt }
            lastSyncedAt = result.completedAt
        }
        syncState = syncService.state
    }
}

private extension Sequence {
    func uniqued<ID: Hashable>(on keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen: Set<ID> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
