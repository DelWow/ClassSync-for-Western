import XCTest
@testable import ClassSync

@MainActor
final class PersistenceTests: XCTestCase {
    func testCoursesAndAssignmentsSaveAndLoad() throws {
        let controller = PersistenceController(inMemory: true)
        let store = SwiftDataAssignmentStore(container: controller.container)
        let assignment = makeAssignment()

        try store.saveCourses(MockData.courses)
        try store.replaceAssignments(with: [assignment])

        XCTAssertEqual(try store.fetchCourses().count, MockData.courses.count)
        XCTAssertEqual(try store.fetchAssignments(), [assignment])
    }

    func testRepeatedAssignmentSaveUpdatesInsteadOfDuplicating() throws {
        let controller = PersistenceController(inMemory: true)
        let store = SwiftDataAssignmentStore(container: controller.container)
        let original = makeAssignment(title: "Original")
        let updated = makeAssignment(title: "Updated")

        try store.replaceAssignments(with: [original])
        try store.replaceAssignments(with: [updated])

        let loaded = try store.fetchAssignments()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.title, "Updated")
    }

    func testReplaceRemovesAssignmentsMissingFromLatestSnapshot() throws {
        let controller = PersistenceController(inMemory: true)
        let store = SwiftDataAssignmentStore(container: controller.container)

        try store.replaceAssignments(with: [makeAssignment(id: "one"), makeAssignment(id: "two")])
        try store.replaceAssignments(with: [makeAssignment(id: "two")])

        XCTAssertEqual(try store.fetchAssignments().map(\.id), ["two"])
    }

    func testDeleteAllDataClearsEveryPersistentRecord() throws {
        let controller = PersistenceController(inMemory: true)
        let store = SwiftDataAssignmentStore(container: controller.container)
        try store.saveCourses(MockData.courses)
        try store.replaceAssignments(with: MockData.assignments)
        try store.updateSyncMetadata(providerID: "mock", attemptedAt: Date(), successfulAt: Date())

        try store.deleteAllData()

        XCTAssertTrue(try store.fetchCourses().isEmpty)
        XCTAssertTrue(try store.fetchAssignments().isEmpty)
        XCTAssertTrue(try store.fetchChanges().isEmpty)
        XCTAssertNil(try store.lastSuccessfulSync(providerID: "mock"))
    }

    func testChangeHistoryAndSyncMetadataPersist() throws {
        let controller = PersistenceController(inMemory: true)
        let store = SwiftDataAssignmentStore(container: controller.container)
        let change = ChangeDetector().detect(previous: [], current: [makeAssignment()]).first!
        let syncDate = Date(timeIntervalSince1970: 10_000)

        try store.saveChanges([change])
        try store.updateSyncMetadata(providerID: "test", attemptedAt: syncDate, successfulAt: syncDate)

        XCTAssertEqual(try store.fetchChanges(), [change])
        XCTAssertEqual(try store.lastSuccessfulSync(providerID: "test"), syncDate)
    }
}
