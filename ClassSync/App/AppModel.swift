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
    @Published private(set) var notificationPermission: NotificationPermissionState = .notDetermined
    @Published private(set) var disabledCourseIDs: Set<String> = []
    @Published private(set) var courseColorOverrides: [String: String] = [:]
    @Published private(set) var dataDeletionMessage: String?
    let calendarIntegration: CalendarIntegrationService
    let providerName: String

    private let providerID: String
    private let store: any AssignmentStore
    private let syncService: SyncService
    private let notificationService: NotificationService
    private let backgroundScheduler: any BackgroundSyncScheduling
    private var hasLoaded = false

    var visibleAssignments: [Assignment] {
        assignments.filter { !disabledCourseIDs.contains($0.courseID) }
    }

    var isUsingMockProvider: Bool { providerID == "mock-brightspace" }

    init(
        provider: any AssignmentProvider,
        store: any AssignmentStore,
        notificationService: NotificationService,
        backgroundScheduler: any BackgroundSyncScheduling,
        calendarIntegration: CalendarIntegrationService
    ) {
        providerID = provider.id
        providerName = provider.name
        self.store = store
        syncService = SyncService(provider: provider, store: store)
        self.notificationService = notificationService
        self.backgroundScheduler = backgroundScheduler
        self.calendarIntegration = calendarIntegration
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        do {
            disabledCourseIDs = Set(UserDefaults.standard.stringArray(forKey: "disabledCourseIDs") ?? [])
            courseColorOverrides = UserDefaults.standard.dictionary(forKey: "courseColorOverrides") as? [String: String] ?? [:]
            courses = try store.fetchCourses()
            assignments = try store.fetchAssignments()
            changes = try store.fetchChanges()
            lastSyncedAt = try store.lastSuccessfulSync(providerID: providerID)

            if isUsingMockProvider && courses.isEmpty && assignments.isEmpty {
                try store.saveCourses(MockData.courses)
                try store.replaceAssignments(with: MockData.assignments)
                courses = MockData.courses
                assignments = MockData.assignments
            }
            Task {
                notificationPermission = await notificationService.permissionState()
                await rescheduleReminders()
            }
            calendarIntegration.refresh()
            configureBackgroundSyncFromPreferences()
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
            await deliverChangeNotifications(result.changes, assignments: result.assignments)
            await rescheduleReminders()
            syncCalendarIfEnabled()
        }
        syncState = syncService.state
    }

    func requestNotificationPermission() async {
        do {
            notificationPermission = try await notificationService.requestPermission()
            if notificationPermission == .authorized {
                await rescheduleReminders()
            }
        } catch {
            notificationPermission = .denied
            AppLogger.notifications.error("Notification authorization request failed")
        }
    }

    func isCourseEnabled(_ courseID: String) -> Bool {
        !disabledCourseIDs.contains(courseID)
    }

    func setCourseEnabled(_ enabled: Bool, courseID: String) {
        if enabled {
            disabledCourseIDs.remove(courseID)
        } else {
            disabledCourseIDs.insert(courseID)
            assignments
                .filter { $0.courseID == courseID }
                .forEach { notificationService.cancelReminders(assignmentID: $0.id) }
        }
        UserDefaults.standard.set(Array(disabledCourseIDs).sorted(), forKey: "disabledCourseIDs")
        if enabled {
            Task { await rescheduleReminders() }
        }
        syncCalendarIfEnabled()
    }

    func colorHex(for courseID: String) -> String {
        if let override = courseColorOverrides[courseID] { return override }
        if let stored = courses.first(where: { $0.id == courseID })?.colorHex { return stored }
        return CourseColorPalette.defaultHex(for: courseID)
    }

    func setCourseColor(_ hex: String, courseID: String) {
        courseColorOverrides[courseID] = hex
        UserDefaults.standard.set(courseColorOverrides, forKey: "courseColorOverrides")
    }

    func updateBackgroundSyncConfiguration(enabled: Bool, intervalMinutes: Int) {
        guard enabled, intervalMinutes > 0 else {
            backgroundScheduler.cancel()
            return
        }
        backgroundScheduler.schedule(interval: TimeInterval(intervalMinutes * 60)) { [weak self] in
            await self?.syncNow()
        }
    }

    func refreshReminderSchedule() async {
        await rescheduleReminders()
    }

    func updateCalendarIntegration(enabled: Bool, calendarID: String?) async {
        if enabled {
            if calendarIntegration.permission != .authorized {
                await calendarIntegration.requestAccess()
            }
            guard calendarIntegration.permission == .authorized else {
                UserDefaults.standard.set(false, forKey: "calendarIntegrationEnabled")
                return
            }
            calendarIntegration.synchronize(
                assignments: visibleAssignments,
                calendarID: calendarID,
                removeMissingEvents: UserDefaults.standard.object(forKey: "removeCancelledCalendarEvents") as? Bool ?? true
            )
        } else {
            calendarIntegration.disableAndRemoveEvents()
        }
    }

    func deleteLocalData() {
        do {
            assignments.forEach { notificationService.cancelReminders(assignmentID: $0.id) }
            calendarIntegration.disableAndRemoveEvents()
            try store.deleteAllData()
            courses.removeAll()
            assignments.removeAll()
            changes.removeAll()
            lastSyncedAt = nil
            disabledCourseIDs.removeAll()
            courseColorOverrides.removeAll()
            UserDefaults.standard.removeObject(forKey: "disabledCourseIDs")
            UserDefaults.standard.removeObject(forKey: "courseColorOverrides")
            UserDefaults.standard.set(false, forKey: "calendarIntegrationEnabled")
            dataDeletionMessage = "Local course, assignment, change, and sync data was deleted."
        } catch {
            AppLogger.database.error("Local data deletion failed")
            dataDeletionMessage = "ClassSync could not delete all local data. Restart the app and try again."
        }
    }

    private func deliverChangeNotifications(_ newChanges: [AssignmentChange], assignments: [Assignment]) async {
        for change in newChanges where shouldNotify(for: change.changeType) {
            if change.changeType == .removed {
                notificationService.cancelReminders(assignmentID: change.assignmentID)
            }
            let assignment = assignments.first { $0.id == change.assignmentID }
            do {
                try await notificationService.sendChangeNotification(change: change, assignment: assignment)
                try store.markChangeNotificationHandled(id: change.id)
                if let index = changes.firstIndex(where: { $0.id == change.id }) {
                    changes[index].notificationHandled = true
                }
            } catch AppError.notificationPermissionDenied {
                notificationPermission = .denied
            } catch {
                AppLogger.notifications.error("Change notification delivery failed")
            }
        }
    }

    private func shouldNotify(for type: AssignmentChangeType) -> Bool {
        let defaults = UserDefaults.standard
        switch type {
        case .created:
            return defaults.object(forKey: "notifyNewAssignments") as? Bool ?? true
        case .dueDate:
            return defaults.object(forKey: "notifyDueDateChanges") as? Bool ?? true
        case .removed:
            return defaults.object(forKey: "notifyRemovedAssignments") as? Bool ?? false
        case .title, .submissionStatus:
            return false
        }
    }

    private func rescheduleReminders() async {
        guard notificationPermission == .authorized else { return }
        let defaults = UserDefaults.standard
        var leadTimes: Set<ReminderLeadTime> = []
        if defaults.object(forKey: "remind24Hours") as? Bool ?? true { leadTimes.insert(.twentyFourHours) }
        if defaults.object(forKey: "remind6Hours") as? Bool ?? true { leadTimes.insert(.sixHours) }
        if defaults.object(forKey: "remind1Hour") as? Bool ?? false { leadTimes.insert(.oneHour) }

        for assignment in visibleAssignments {
            do {
                try await notificationService.rescheduleReminders(for: assignment, leadTimes: leadTimes)
            } catch {
                AppLogger.notifications.error("Reminder scheduling failed")
            }
        }
    }

    private func configureBackgroundSyncFromPreferences() {
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "automaticallySync") as? Bool ?? true
        let minutes = defaults.object(forKey: "syncIntervalMinutes") as? Int ?? 60
        updateBackgroundSyncConfiguration(enabled: enabled, intervalMinutes: minutes)
    }

    private func syncCalendarIfEnabled() {
        guard UserDefaults.standard.bool(forKey: "calendarIntegrationEnabled") else { return }
        let calendarID = UserDefaults.standard.string(forKey: "calendarIntegrationCalendarID")
        calendarIntegration.synchronize(
            assignments: visibleAssignments,
            calendarID: calendarID,
            removeMissingEvents: UserDefaults.standard.object(forKey: "removeCancelledCalendarEvents") as? Bool ?? true
        )
    }
}

private extension Sequence {
    func uniqued<ID: Hashable>(on keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen: Set<ID> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
