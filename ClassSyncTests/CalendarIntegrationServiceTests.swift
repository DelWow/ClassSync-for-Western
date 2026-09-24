import XCTest
@testable import ClassSync

@MainActor
final class CalendarIntegrationServiceTests: XCTestCase {
    func testSynchronizationCreatesThenUpdatesWithoutDuplicates() {
        let client = CalendarClientStub()
        let links = MemoryCalendarLinkStore()
        let service = CalendarIntegrationService(client: client, linkStore: links)
        let assignment = makeAssignment(
            id: "one",
            dueDate: Date(timeIntervalSince1970: 2_000),
            url: URL(string: "https://westernu.brightspace.com/d2l/item/one")
        )

        service.synchronize(assignments: [assignment], calendarID: "calendar")
        service.synchronize(assignments: [assignment], calendarID: "calendar")

        XCTAssertEqual(client.upserts.count, 2)
        XCTAssertNil(client.upserts[0].eventID)
        XCTAssertEqual(client.upserts[1].eventID, "event-1")
        XCTAssertEqual(links.links, ["one": "event-1"])
        XCTAssertEqual(client.upserts[0].draft.startDate, assignment.dueDate)
        XCTAssertEqual(client.upserts[0].draft.url, assignment.url)
    }

    func testSynchronizationRemovesEventsMissingFromLatestSnapshot() {
        let client = CalendarClientStub()
        let links = MemoryCalendarLinkStore(links: ["removed": "event-old"])
        let service = CalendarIntegrationService(client: client, linkStore: links)

        service.synchronize(assignments: [], calendarID: "calendar")

        XCTAssertEqual(client.removedIDs, ["event-old"])
        XCTAssertTrue(links.links.isEmpty)
    }

    func testSynchronizationCanPreserveCancelledEventsByPreference() {
        let client = CalendarClientStub()
        let links = MemoryCalendarLinkStore(links: ["removed": "event-old"])
        let service = CalendarIntegrationService(client: client, linkStore: links)

        service.synchronize(assignments: [], calendarID: "calendar", removeMissingEvents: false)

        XCTAssertTrue(client.removedIDs.isEmpty)
        XCTAssertEqual(links.links, ["removed": "event-old"])
    }

    func testCreatesDedicatedCalendar() {
        let client = CalendarClientStub()
        let service = CalendarIntegrationService(client: client, linkStore: MemoryCalendarLinkStore())
        service.refresh()

        XCTAssertEqual(service.createClassSyncCalendar(), "classsync-calendar")
        XCTAssertEqual(client.createdCalendarTitles, ["ClassSync"])
    }

    func testDisablingRemovesOnlyLinkedEvents() {
        let client = CalendarClientStub()
        let links = MemoryCalendarLinkStore(links: ["one": "event-1", "two": "event-2"])
        let service = CalendarIntegrationService(client: client, linkStore: links)

        service.disableAndRemoveEvents()

        XCTAssertEqual(Set(client.removedIDs), ["event-1", "event-2"])
        XCTAssertTrue(links.links.isEmpty)
    }

    func testDeniedPermissionDoesNotCreateEvents() {
        let client = CalendarClientStub(permission: .denied)
        let service = CalendarIntegrationService(client: client, linkStore: MemoryCalendarLinkStore())

        service.synchronize(assignments: [makeAssignment()], calendarID: "calendar")

        XCTAssertTrue(client.upserts.isEmpty)
        XCTAssertEqual(service.errorMessage, AppError.calendarPermissionDenied.localizedDescription)
    }
}

@MainActor
private final class CalendarClientStub: CalendarEventClient {
    struct Upsert {
        let eventID: String?
        let draft: CalendarEventDraft
        let calendarID: String
    }

    var permission: CalendarPermissionState
    var upserts: [Upsert] = []
    var removedIDs: [String] = []
    var createdCalendarTitles: [String] = []

    init(permission: CalendarPermissionState = .authorized) {
        self.permission = permission
    }

    func authorizationStatus() -> CalendarPermissionState { permission }
    func requestFullAccess() async throws -> Bool { permission == .authorized }
    func writableCalendars() -> [CalendarDescriptor] {
        [CalendarDescriptor(id: "calendar", title: "ClassSync", sourceTitle: "iCloud")]
    }
    func defaultCalendarID() -> String? { "calendar" }
    func createCalendar(title: String) throws -> CalendarDescriptor {
        createdCalendarTitles.append(title)
        return CalendarDescriptor(id: "classsync-calendar", title: title, sourceTitle: "iCloud")
    }

    func upsert(eventID: String?, draft: CalendarEventDraft, calendarID: String) throws -> String {
        upserts.append(Upsert(eventID: eventID, draft: draft, calendarID: calendarID))
        return eventID ?? "event-\(upserts.count)"
    }

    func remove(eventID: String) throws {
        removedIDs.append(eventID)
    }
}

private final class MemoryCalendarLinkStore: CalendarEventLinkStoring {
    var links: [String: String]
    init(links: [String: String] = [:]) { self.links = links }
}
