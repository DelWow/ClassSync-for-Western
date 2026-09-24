import XCTest
@testable import ClassSync

@MainActor
final class SyncServiceTests: XCTestCase {
    func testSyncStoresLatestSnapshotAndSuccessfulTime() async throws {
        let existing = makeAssignment(title: "Old")
        let current = makeAssignment(title: "New")
        let store = InMemoryAssignmentStore(assignments: [existing])
        let provider = StaticProvider(assignments: [current])
        let service = SyncService(provider: provider, store: store)

        let result = await service.sync()

        XCTAssertEqual(result?.assignments, [current])
        XCTAssertEqual(store.assignments, [current])
        XCTAssertEqual(result?.changes.map(\.changeType), [.title])
        guard case .success = service.state else {
            return XCTFail("Expected successful sync state")
        }
        XCTAssertNotNil(try store.lastSuccessfulSync(providerID: provider.id))
    }

    func testRepeatedIdenticalSyncDoesNotDuplicateAssignmentsOrChanges() async {
        let assignment = makeAssignment()
        let store = InMemoryAssignmentStore()
        let service = SyncService(provider: StaticProvider(assignments: [assignment]), store: store)

        let first = await service.sync()
        let second = await service.sync()

        XCTAssertEqual(store.assignments.count, 1)
        XCTAssertEqual(first?.changes.map(\.changeType), [.created])
        XCTAssertTrue(second?.changes.isEmpty == true)
        XCTAssertEqual(store.changes.count, 1)
    }

    func testProviderFailureProducesUserSafeFailedState() async {
        let service = SyncService(provider: FailingProvider(), store: InMemoryAssignmentStore())

        let result = await service.sync()

        XCTAssertNil(result)
        XCTAssertEqual(service.state, .failed("Your session expired. Reconnect your account and try again."))
    }
}

private struct StaticProvider: AssignmentProvider {
    let id = "static"
    let name = "Static"
    let capabilities: ProviderCapabilities = [.courses, .assignments]
    var assignments: [Assignment]

    func authenticate() async throws {}
    func fetchCourses() async throws -> [Course] { MockData.courses }
    func fetchAssignments() async throws -> [Assignment] { assignments }
}

private struct FailingProvider: AssignmentProvider {
    let id = "failing"
    let name = "Failing"
    let capabilities: ProviderCapabilities = []

    func authenticate() async throws {}
    func fetchCourses() async throws -> [Course] { throw ProviderError.authenticationExpired }
    func fetchAssignments() async throws -> [Assignment] { throw ProviderError.authenticationExpired }
}
