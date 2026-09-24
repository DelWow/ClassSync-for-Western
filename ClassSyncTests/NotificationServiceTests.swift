import UserNotifications
import XCTest
@testable import ClassSync

final class NotificationRequestFactoryTests: XCTestCase {
    private let factory = NotificationRequestFactory()

    func testDueDateNotificationContainsOldAndNewValues() {
        let change = makeChange(type: .dueDate, oldValue: "Oct 10, 11:59 PM", newValue: "Oct 13, 11:59 PM")

        let request = factory.changeRequest(for: change, assignment: makeAssignment())

        XCTAssertEqual(request?.content.subtitle, "Due date changed")
        XCTAssertEqual(request?.content.body, "Oct 10, 11:59 PM → Oct 13, 11:59 PM")
        XCTAssertEqual(request?.content.userInfo["assignmentID"] as? String, change.assignmentID)
    }

    func testUnsupportedChangeDoesNotCreateNotification() {
        XCTAssertNil(factory.changeRequest(for: makeChange(type: .title), assignment: nil))
    }

    func testReminderIdentifiersAreStableAndRequestsAreFutureOnly() {
        let now = Date(timeIntervalSince1970: 10_000)
        let assignment = makeAssignment(dueDate: now.addingTimeInterval(90_000))

        let requests = factory.reminderRequests(
            for: assignment,
            leadTimes: [.twentyFourHours, .sixHours, .oneHour],
            now: now
        )

        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(Set(requests.map(\.identifier)).count, 3)
        XCTAssertTrue(requests.allSatisfy { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? 0 > 0 })
    }

    func testSubmittedAndPastAssignmentsDoNotScheduleReminders() {
        let now = Date(timeIntervalSince1970: 10_000)
        let submitted = makeAssignment(dueDate: now.addingTimeInterval(100_000), status: .submitted)
        let past = makeAssignment(dueDate: now.addingTimeInterval(100))

        XCTAssertTrue(factory.reminderRequests(for: submitted, leadTimes: [.oneHour], now: now).isEmpty)
        XCTAssertTrue(factory.reminderRequests(for: past, leadTimes: [.oneHour], now: now).isEmpty)
    }
}

@MainActor
final class NotificationServiceTests: XCTestCase {
    func testDeniedPermissionIsReported() async throws {
        let center = FakeNotificationCenter(status: .denied)
        let service = NotificationService(center: center)

        do {
            try await service.sendChangeNotification(change: makeChange(type: .created), assignment: makeAssignment())
            XCTFail("Expected permission error")
        } catch {
            XCTAssertEqual(error as? AppError, .notificationPermissionDenied)
        }
    }

    func testChangeIsSubmittedOnlyOncePerServiceLifetime() async throws {
        let center = FakeNotificationCenter(status: .authorized)
        let service = NotificationService(center: center)
        let change = makeChange(type: .created)

        try await service.sendChangeNotification(change: change, assignment: makeAssignment())
        try await service.sendChangeNotification(change: change, assignment: makeAssignment())

        XCTAssertEqual(center.addedRequests.count, 1)
    }

    func testReschedulingCancelsAllOldIdentifiersBeforeAdding() async throws {
        let center = FakeNotificationCenter(status: .authorized)
        let service = NotificationService(center: center)
        let now = Date(timeIntervalSince1970: 10_000)
        let assignment = makeAssignment(dueDate: now.addingTimeInterval(100_000))

        try await service.rescheduleReminders(for: assignment, leadTimes: [.sixHours], now: now)

        XCTAssertEqual(center.removedIdentifiers.count, ReminderLeadTime.allCases.count)
        XCTAssertEqual(center.addedRequests.count, 1)
    }
}

private final class FakeNotificationCenter: UserNotificationCenterClient, @unchecked Sendable {
    var status: UNAuthorizationStatus
    var requestResult = true
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { requestResult }
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func add(_ request: UNNotificationRequest) async throws { addedRequests.append(request) }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { removedIdentifiers.append(contentsOf: identifiers) }
}

private func makeChange(
    type: AssignmentChangeType,
    oldValue: String? = nil,
    newValue: String? = "Assignment"
) -> AssignmentChange {
    AssignmentChange(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        assignmentID: "assignment-1",
        courseID: "course-1",
        courseCode: "COURSE 1",
        assignmentTitle: "Assignment",
        changeType: type,
        oldValue: oldValue,
        newValue: newValue,
        detectedAt: Date(timeIntervalSince1970: 1_000),
        notificationHandled: false
    )
}
