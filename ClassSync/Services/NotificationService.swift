import Foundation
import UserNotifications

enum NotificationPermissionState: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

enum ReminderLeadTime: Int, CaseIterable, Sendable {
    case twentyFourHours = 86_400
    case sixHours = 21_600
    case oneHour = 3_600

    var hours: Int { rawValue / 3_600 }
}

protocol UserNotificationCenterClient: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

struct SystemUserNotificationCenterClient: UserNotificationCenterClient, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

struct NotificationRequestFactory: Sendable {
    func changeRequest(for change: AssignmentChange, assignment: Assignment?) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = "\(change.courseCode) — \(change.assignmentTitle)"
        content.sound = .default
        content.userInfo["assignmentID"] = change.assignmentID
        if let assignment, let url = AssignmentURLValidator.validatedURL(for: assignment)?.absoluteString {
            content.userInfo["url"] = url
            content.userInfo["source"] = assignment.source.rawValue
        }

        switch change.changeType {
        case .dueDate:
            content.subtitle = "Due date changed"
            content.body = "\(change.oldValue ?? "No due date") → \(change.newValue ?? "No due date")"
        case .created:
            content.subtitle = "New assignment"
            content.body = change.newValue ?? change.assignmentTitle
        case .removed:
            content.subtitle = "Assignment removed"
            content.body = change.oldValue ?? change.assignmentTitle
        case .title, .submissionStatus:
            return nil
        }

        return UNNotificationRequest(
            identifier: changeIdentifier(change.id),
            content: content,
            trigger: nil
        )
    }

    func reminderRequests(
        for assignment: Assignment,
        leadTimes: Set<ReminderLeadTime>,
        now: Date = Date()
    ) -> [UNNotificationRequest] {
        guard assignment.status != .submitted, let dueDate = assignment.dueDate else { return [] }

        return leadTimes.compactMap { leadTime in
            let fireDate = dueDate.addingTimeInterval(-TimeInterval(leadTime.rawValue))
            let delay = fireDate.timeIntervalSince(now)
            guard delay >= 1 else { return nil }

            let content = UNMutableNotificationContent()
            content.title = "\(assignment.courseCode) — \(assignment.title)"
            content.subtitle = "Due in \(leadTime.hours) \(leadTime.hours == 1 ? "hour" : "hours")"
            content.body = "Due \(dueDate.formatted(date: .abbreviated, time: .shortened))"
            content.sound = .default
            content.userInfo["assignmentID"] = assignment.id
            if let url = AssignmentURLValidator.validatedURL(for: assignment)?.absoluteString {
                content.userInfo["url"] = url
                content.userInfo["source"] = assignment.source.rawValue
            }

            return UNNotificationRequest(
                identifier: reminderIdentifier(assignmentID: assignment.id, leadTime: leadTime),
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            )
        }
        .sorted { $0.identifier < $1.identifier }
    }

    func changeIdentifier(_ id: UUID) -> String {
        "change-\(id.uuidString.lowercased())"
    }

    func reminderIdentifier(assignmentID: String, leadTime: ReminderLeadTime) -> String {
        "reminder-\(assignmentID)-\(leadTime.hours)h"
    }

    func reminderIdentifiers(assignmentID: String) -> [String] {
        ReminderLeadTime.allCases.map { reminderIdentifier(assignmentID: assignmentID, leadTime: $0) }
    }
}

@MainActor
final class NotificationService {
    private let center: any UserNotificationCenterClient
    private let factory: NotificationRequestFactory
    private var submittedChangeIDs: Set<UUID> = []

    init(
        center: any UserNotificationCenterClient = SystemUserNotificationCenterClient(),
        factory: NotificationRequestFactory = NotificationRequestFactory()
    ) {
        self.center = center
        self.factory = factory
    }

    func permissionState() async -> NotificationPermissionState {
        switch await center.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            .authorized
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .denied
        }
    }

    func requestPermission() async throws -> NotificationPermissionState {
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted ? .authorized : .denied
    }

    func sendChangeNotification(change: AssignmentChange, assignment: Assignment?) async throws {
        guard !change.notificationHandled, !submittedChangeIDs.contains(change.id) else { return }
        guard await permissionState() == .authorized else { throw AppError.notificationPermissionDenied }
        guard let request = factory.changeRequest(for: change, assignment: assignment) else { return }

        try await center.add(request)
        submittedChangeIDs.insert(change.id)
    }

    func rescheduleReminders(
        for assignment: Assignment,
        leadTimes: Set<ReminderLeadTime>,
        now: Date = Date()
    ) async throws {
        center.removePendingNotificationRequests(
            withIdentifiers: factory.reminderIdentifiers(assignmentID: assignment.id)
        )
        guard await permissionState() == .authorized else { return }
        for request in factory.reminderRequests(for: assignment, leadTimes: leadTimes, now: now) {
            try await center.add(request)
        }
    }

    func cancelReminders(assignmentID: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: factory.reminderIdentifiers(assignmentID: assignmentID)
        )
    }
}
