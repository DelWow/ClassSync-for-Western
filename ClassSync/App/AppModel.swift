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
    @Published private(set) var calendarFeedConnected = false
    @Published private(set) var calendarFeedMessage: String?
    @Published private(set) var syllabusImportMessage: String?
    @Published private(set) var emailSuggestions: [EmailDeadlineSuggestion] = []
    @Published private(set) var emailScanMessage: String?
    @Published private(set) var isScanningEmail = false
    let calendarIntegration: CalendarIntegrationService
    let providerName: String

    private let providerID: String
    private let store: any AssignmentStore
    private let syncService: SyncService
    private let notificationService: NotificationService
    private let backgroundScheduler: any BackgroundSyncScheduling
    private let syllabusImportService: SyllabusImportService
    private let calendarFeedConfiguration: BrightspaceCalendarFeedConfiguration
    private let calendarFeedClient: BrightspaceCalendarFeedClient
    private let schoolEmailService: AppleMailMessageService
    private let emailChangeDetector: EmailDeadlineChangeDetector
    private let showsDevelopmentSamplesWhenEmpty: Bool
    private let changeDetector = ChangeDetector()
    private let sourceReconciler = SourceReconciler()
    private var processedEmailMessageIDs: Set<String> = []
    private var hasLoaded = false

    var visibleAssignments: [Assignment] {
        sourceReconciler.assignments(assignments.filter { !disabledCourseIDs.contains($0.courseID) })
    }

    var visibleCourses: [Course] { sourceReconciler.courses(courses) }

    var isUsingMockProvider: Bool {
        let mockCourseIDs = Set(MockData.courses.map(\.id))
        return courses.contains { mockCourseIDs.contains($0.id) }
    }

    init(
        provider: any AssignmentProvider,
        store: any AssignmentStore,
        notificationService: NotificationService,
        backgroundScheduler: any BackgroundSyncScheduling,
        calendarIntegration: CalendarIntegrationService,
        syllabusImportService: SyllabusImportService = SyllabusImportService(),
        calendarFeedConfiguration: BrightspaceCalendarFeedConfiguration = BrightspaceCalendarFeedConfiguration(),
        calendarFeedClient: BrightspaceCalendarFeedClient = BrightspaceCalendarFeedClient(),
        schoolEmailService: AppleMailMessageService = AppleMailMessageService(),
        emailChangeDetector: EmailDeadlineChangeDetector = EmailDeadlineChangeDetector(),
        showsDevelopmentSamplesWhenEmpty: Bool = false
    ) {
        providerID = provider.id
        providerName = provider.name
        self.store = store
        syncService = SyncService(provider: provider, store: store)
        self.notificationService = notificationService
        self.backgroundScheduler = backgroundScheduler
        self.calendarIntegration = calendarIntegration
        self.syllabusImportService = syllabusImportService
        self.calendarFeedConfiguration = calendarFeedConfiguration
        self.calendarFeedClient = calendarFeedClient
        self.schoolEmailService = schoolEmailService
        self.emailChangeDetector = emailChangeDetector
        self.showsDevelopmentSamplesWhenEmpty = showsDevelopmentSamplesWhenEmpty
    }

    func load() {
        guard !hasLoaded else { return }
        hasLoaded = true

        do {
            disabledCourseIDs = Set(UserDefaults.standard.stringArray(forKey: "disabledCourseIDs") ?? [])
            courseColorOverrides = UserDefaults.standard.dictionary(forKey: "courseColorOverrides") as? [String: String] ?? [:]
            processedEmailMessageIDs = Set(UserDefaults.standard.stringArray(forKey: "processedSchoolEmailMessageIDs") ?? [])
            calendarFeedConnected = calendarFeedConfiguration.isConnected()
            courses = try store.fetchCourses()
            assignments = try store.fetchAssignments()
            changes = try store.fetchChanges()
            lastSyncedAt = try store.lastSuccessfulSync(providerID: providerID)

            if showsDevelopmentSamplesWhenEmpty,
               !calendarFeedConnected,
               courses.isEmpty,
               assignments.isEmpty {
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
            if calendarFeedConnected,
               UserDefaults.standard.object(forKey: "automaticallySync") as? Bool ?? true {
                Task { await syncNow() }
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
            await deliverChangeNotifications(result.changes, assignments: result.assignments)
            await rescheduleReminders()
            syncCalendarIfEnabled()
        }
        syncState = syncService.state
        if UserDefaults.standard.bool(forKey: "schoolEmailScanningEnabled") {
            await scanSchoolEmail()
        }
    }

    func loadSyllabus(at url: URL) throws -> SyllabusImportResult {
        try syllabusImportService.load(url: url)
    }

    func importSyllabus(_ result: SyllabusImportResult) {
        let (course, importedAssignments) = syllabusImportService.makeModels(from: result)
        guard !importedAssignments.isEmpty else {
            syllabusImportMessage = "Select at least one detected item to import."
            return
        }

        do {
            try discardDevelopmentSamplesIfNeeded()
            let previous = assignments
            let mergedCourses = (courses.filter { $0.id != course.id } + [course])
                .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
            var assignmentsByID = Dictionary(uniqueKeysWithValues: assignments
                .filter { !($0.source == .syllabus && $0.courseID == course.id) }
                .map { ($0.id, $0) })
            importedAssignments.forEach { assignmentsByID[$0.id] = $0 }
            let mergedAssignments = assignmentsByID.values.sorted(by: Assignment.dueDateAscending)
            let detectedChanges = changeDetector.detect(previous: previous, current: mergedAssignments)

            try store.replaceCourses(with: mergedCourses)
            try store.replaceAssignments(with: mergedAssignments)
            try store.saveChanges(detectedChanges)
            courses = mergedCourses
            assignments = mergedAssignments
            changes = (detectedChanges + changes).uniqued(on: \.id).sorted { $0.detectedAt > $1.detectedAt }
            syllabusImportMessage = "Imported \(importedAssignments.count) item\(importedAssignments.count == 1 ? "" : "s") for \(course.code)."
            Task {
                await rescheduleReminders()
                syncCalendarIfEnabled()
            }
        } catch {
            AppLogger.imports.error("Syllabus import persistence failed")
            syllabusImportMessage = "The syllabus was read, but its assignments could not be saved."
        }
    }

    func connectBrightspaceCalendarFeed(_ urlString: String) async {
        do {
            try calendarFeedConfiguration.save(urlString: urlString)
            await calendarFeedClient.invalidateCache()
            calendarFeedConnected = true
            do {
                try discardDevelopmentSamplesIfNeeded()
            } catch {
                AppLogger.database.error("Development sample cleanup failed")
            }
            calendarFeedMessage = "Calendar feed connected. Syncing now…"
            await syncNow()
            if case .failed = syncState {
                calendarFeedMessage = "The feed was saved, but the first sync failed. Check the URL and try Sync Now."
            } else {
                calendarFeedMessage = "Brightspace calendar feed connected."
            }
        } catch {
            calendarFeedConnected = false
            calendarFeedMessage = (error as? LocalizedError)?.errorDescription ?? "The calendar feed could not be connected."
        }
    }

    func disconnectBrightspaceCalendarFeed(removeImportedData: Bool = true) {
        do {
            try calendarFeedConfiguration.disconnect()
            Task { await calendarFeedClient.invalidateCache() }
            calendarFeedConnected = false
            if removeImportedData {
                courses.removeAll { $0.source == .brightspaceCalendar }
                assignments.removeAll { $0.source == .brightspaceCalendar }
                try store.replaceCourses(with: courses)
                try store.replaceAssignments(with: assignments)
                syncCalendarIfEnabled()
            }
            calendarFeedMessage = removeImportedData
                ? "Calendar feed disconnected and its imported events were removed."
                : "Calendar feed disconnected."
        } catch {
            calendarFeedMessage = "ClassSync could not fully disconnect the calendar feed. Try again."
        }
    }

    func scanSchoolEmail() async {
        guard !isScanningEmail else { return }
        isScanningEmail = true
        defer { isScanningEmail = false }
        do {
            let messages = try await schoolEmailService.recentWesternMessages()
            let detected = emailChangeDetector.detect(
                messages: messages,
                assignments: visibleAssignments,
                courses: visibleCourses,
                processedMessageIDs: processedEmailMessageIDs
            )
            emailSuggestions = detected
            emailScanMessage = detected.isEmpty
                ? "No unreviewed deadline changes were detected in recent Western email."
                : "Review \(detected.count) possible deadline change\(detected.count == 1 ? "" : "s")."
        } catch {
            emailScanMessage = (error as? LocalizedError)?.errorDescription ?? "ClassSync could not scan Apple Mail."
        }
    }

    func applyEmailSuggestion(_ suggestion: EmailDeadlineSuggestion) async {
        guard let index = assignments.firstIndex(where: { $0.id == suggestion.assignmentID }) else {
            dismissEmailSuggestion(suggestion)
            return
        }
        let oldAssignments = assignments
        let existing = assignments[index]
        assignments[index] = Assignment(
            id: existing.id,
            externalID: existing.externalID,
            courseID: existing.courseID,
            courseName: existing.courseName,
            courseCode: existing.courseCode,
            title: existing.title,
            dueDate: suggestion.proposedDueDate,
            source: existing.source,
            url: existing.url,
            status: suggestion.proposedDueDate < Date() ? .overdue : .upcoming,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        assignments.sort(by: Assignment.dueDateAscending)
        let detectedChanges = changeDetector.detect(previous: oldAssignments, current: assignments)
            .filter { $0.assignmentID == suggestion.assignmentID && $0.changeType == .dueDate }
        do {
            try store.replaceAssignments(with: assignments)
            try store.saveChanges(detectedChanges)
            changes = (detectedChanges + changes).uniqued(on: \.id).sorted { $0.detectedAt > $1.detectedAt }
            markEmailMessageProcessed(suggestion.messageID)
            emailSuggestions.removeAll { $0.id == suggestion.id }
            emailScanMessage = "Applied the email deadline update for \(suggestion.assignmentTitle)."
            await deliverChangeNotifications(detectedChanges, assignments: assignments)
            await rescheduleReminders()
            syncCalendarIfEnabled()
        } catch {
            assignments = oldAssignments
            emailScanMessage = "The suggested change could not be saved."
        }
    }

    func dismissEmailSuggestion(_ suggestion: EmailDeadlineSuggestion) {
        markEmailMessageProcessed(suggestion.messageID)
        emailSuggestions.removeAll { $0.id == suggestion.id }
        emailScanMessage = "Dismissed the email suggestion."
    }

    func removeImportedSyllabusCourse(_ course: Course) {
        guard course.source == .syllabus else { return }
        let previousCourses = courses
        let previousAssignments = assignments
        let removedAssignments = assignments.filter { $0.source == .syllabus && $0.courseID == course.id }
        courses.removeAll { $0.id == course.id }
        assignments.removeAll { $0.source == .syllabus && $0.courseID == course.id }
        do {
            try store.replaceCourses(with: courses)
            try store.replaceAssignments(with: assignments)
            removedAssignments.forEach { notificationService.cancelReminders(assignmentID: $0.id) }
            disabledCourseIDs.remove(course.id)
            courseColorOverrides.removeValue(forKey: course.id)
            UserDefaults.standard.set(Array(disabledCourseIDs).sorted(), forKey: "disabledCourseIDs")
            UserDefaults.standard.set(courseColorOverrides, forKey: "courseColorOverrides")
            syllabusImportMessage = "Removed the imported syllabus for \(course.code)."
            Task { await rescheduleReminders() }
            syncCalendarIfEnabled()
        } catch {
            courses = previousCourses
            assignments = previousAssignments
            syllabusImportMessage = "The imported course could not be removed."
        }
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
            UserDefaults.standard.removeObject(forKey: "processedSchoolEmailMessageIDs")
            UserDefaults.standard.set(false, forKey: "calendarIntegrationEnabled")
            UserDefaults.standard.set(false, forKey: "schoolEmailScanningEnabled")
            try? calendarFeedConfiguration.disconnect()
            calendarFeedConnected = false
            calendarFeedMessage = nil
            emailSuggestions.removeAll()
            processedEmailMessageIDs.removeAll()
            Task { await calendarFeedClient.invalidateCache() }
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

    private func markEmailMessageProcessed(_ id: String) {
        processedEmailMessageIDs.insert(id)
        if processedEmailMessageIDs.count > 5_000 {
            processedEmailMessageIDs = Set(processedEmailMessageIDs.sorted().suffix(5_000))
        }
        UserDefaults.standard.set(Array(processedEmailMessageIDs).sorted(), forKey: "processedSchoolEmailMessageIDs")
    }

    private func discardDevelopmentSamplesIfNeeded() throws {
        guard showsDevelopmentSamplesWhenEmpty, isUsingMockProvider else { return }
        let previousCourses = courses
        let previousAssignments = assignments
        let mockCourseIDs = Set(MockData.courses.map(\.id))
        let mockAssignmentIDs = Set(MockData.assignments.map(\.id))
        courses.removeAll { mockCourseIDs.contains($0.id) }
        assignments.removeAll { mockAssignmentIDs.contains($0.id) }
        do {
            try store.replaceCourses(with: courses)
            try store.replaceAssignments(with: assignments)
        } catch {
            courses = previousCourses
            assignments = previousAssignments
            throw error
        }
    }
}

private extension Sequence {
    func uniqued<ID: Hashable>(on keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen: Set<ID> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
