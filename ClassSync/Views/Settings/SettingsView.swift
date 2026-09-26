import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SettingsContentView(appModel: appModel)
            .frame(width: 660, height: 700)
    }
}

struct SettingsContentView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var calendarIntegration: CalendarIntegrationService
    @StateObject private var launchAtLogin = LaunchAtLoginService()

    @AppStorage("automaticallySync") private var automaticallySync = true
    @AppStorage("showDueTodayCount") private var showDueTodayCount = true
    @AppStorage("syncIntervalMinutes") private var syncIntervalMinutes = 60
    @AppStorage("notifyNewAssignments") private var notifyNewAssignments = true
    @AppStorage("notifyDueDateChanges") private var notifyDueDateChanges = true
    @AppStorage("notifyRemovedAssignments") private var notifyRemovedAssignments = false
    @AppStorage("remind24Hours") private var remind24Hours = true
    @AppStorage("remind6Hours") private var remind6Hours = true
    @AppStorage("remind1Hour") private var remind1Hour = false
    @AppStorage("calendarIntegrationEnabled") private var calendarIntegrationEnabled = false
    @AppStorage("calendarIntegrationCalendarID") private var calendarIntegrationCalendarID = ""
    @AppStorage("removeCancelledCalendarEvents") private var removeCancelledCalendarEvents = true
    @AppStorage("schoolEmailScanningEnabled") private var schoolEmailScanningEnabled = false
    @State private var confirmsDataDeletion = false
    @State private var showsSyllabusPicker = false
    @State private var showsSyllabusReview = false
    @State private var syllabusReview: SyllabusImportResult?
    @State private var syllabusPickerMessage: String?
    @State private var calendarFeedURL = ""
    @State private var showsEmailReview = false
    @State private var syllabusCoursePendingRemoval: Course?

    init(appModel: AppModel) {
        self.appModel = appModel
        calendarIntegration = appModel.calendarIntegration
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Automatically sync", isOn: $automaticallySync)
                    .onChange(of: automaticallySync) { _, enabled in
                        appModel.updateBackgroundSyncConfiguration(enabled: enabled, intervalMinutes: syncIntervalMinutes)
                    }
                Toggle("Show today's assignment count in the menu bar", isOn: $showDueTodayCount)
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { launchAtLogin.state == .enabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                if launchAtLogin.state == .requiresApproval {
                    Button("Review Login Items in System Settings") {
                        launchAtLogin.openSystemSettings()
                    }
                } else if case let .failed(message) = launchAtLogin.state {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Sync") {
                Picker("Frequency", selection: $syncIntervalMinutes) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("Manual only").tag(0)
                }
                .disabled(!automaticallySync)
                .onChange(of: syncIntervalMinutes) { _, minutes in
                    appModel.updateBackgroundSyncConfiguration(enabled: automaticallySync, intervalMinutes: minutes)
                }
                Text("macOS may delay background work to preserve battery life.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Course Sources") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Syllabus")
                        Text("Import detected dates locally and review every item before saving.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Import Syllabus…") { showsSyllabusPicker = true }
                }
                if let message = syllabusPickerMessage ?? appModel.syllabusImportMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Brightspace Calendar Feed") {
                Text("Copy your private calendar subscription URL from Brightspace. It is treated like a password and stored only in macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if appModel.calendarFeedConnected {
                    LabeledContent("Status", value: "Connected")
                    Button("Disconnect and Remove Feed Events", role: .destructive) {
                        appModel.disconnectBrightspaceCalendarFeed(removeImportedData: true)
                        calendarFeedURL = ""
                    }
                } else {
                    SecureField("Private Brightspace calendar URL", text: $calendarFeedURL)
                        .textContentType(.URL)
                    HStack {
                        Spacer()
                        Button("Connect Feed") {
                            let value = calendarFeedURL
                            Task {
                                await appModel.connectBrightspaceCalendarFeed(value)
                                if appModel.calendarFeedConnected { calendarFeedURL = "" }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(calendarFeedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if let message = appModel.calendarFeedMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("School Email") {
                Toggle("Check Western email in Apple Mail", isOn: $schoolEmailScanningEnabled)
                Text("ClassSync scans only recent messages in an @uwo.ca or @westernu.ca account already configured in Apple Mail. Message contents are processed on this Mac and are not saved. Suggested changes always require review.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button(appModel.isScanningEmail ? "Scanning…" : "Scan Recent Email") {
                        Task {
                            await appModel.scanSchoolEmail()
                            showsEmailReview = !appModel.emailSuggestions.isEmpty
                        }
                    }
                    .disabled(!schoolEmailScanningEnabled || appModel.isScanningEmail)
                    Spacer()
                    if !appModel.emailSuggestions.isEmpty {
                        Button("Review \(appModel.emailSuggestions.count) Suggestion\(appModel.emailSuggestions.count == 1 ? "" : "s")") {
                            showsEmailReview = true
                        }
                    }
                }
                if let message = appModel.emailScanMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Notifications") {
                Text("ClassSync uses notifications for new assignments, due-date changes, removals, and the deadline reminders you select.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    LabeledContent("Permission", value: permissionDescription)
                    Spacer()
                    if appModel.notificationPermission != .authorized {
                        Button("Enable Notifications") {
                            Task { await appModel.requestNotificationPermission() }
                        }
                    }
                }
                Toggle("New assignments", isOn: $notifyNewAssignments)
                Toggle("Due-date changes", isOn: $notifyDueDateChanges)
                Toggle("Removed assignments", isOn: $notifyRemovedAssignments)
                Toggle("24-hour reminders", isOn: $remind24Hours)
                    .onChange(of: remind24Hours) { _, _ in refreshReminders() }
                Toggle("6-hour reminders", isOn: $remind6Hours)
                    .onChange(of: remind6Hours) { _, _ in refreshReminders() }
                Toggle("1-hour reminders", isOn: $remind1Hour)
                    .onChange(of: remind1Hour) { _, _ in refreshReminders() }
            }

            Section("Courses") {
                if appModel.visibleCourses.isEmpty {
                    Text("No courses available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.visibleCourses) { course in
                        HStack {
                            Toggle(
                                course.code,
                                isOn: Binding(
                                    get: { appModel.isCourseEnabled(course.id) },
                                    set: { appModel.setCourseEnabled($0, courseID: course.id) }
                                )
                            )

                            Picker(
                                "Color",
                                selection: Binding(
                                    get: { appModel.colorHex(for: course.id) },
                                    set: { appModel.setCourseColor($0, courseID: course.id) }
                                )
                            ) {
                                ForEach(CourseColorPalette.choices, id: \.hex) { choice in
                                    Label {
                                        Text(choice.name)
                                    } icon: {
                                        Circle()
                                            .fill(Color(hex: choice.hex) ?? .secondary)
                                    }
                                    .tag(choice.hex)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)

                            if course.source == .syllabus {
                                Button(role: .destructive) {
                                    syllabusCoursePendingRemoval = course
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("Remove this imported syllabus and its assignments")
                                .accessibilityLabel("Remove imported syllabus for \(course.code)")
                            }
                        }
                        Text(course.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Apple Calendar") {
                Text("Optionally keep assignment deadlines in a writable Apple Calendar. Enabling this requests full calendar access so ClassSync can update and remove only the events it creates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Sync assignment deadlines", isOn: $calendarIntegrationEnabled)
                    .onChange(of: calendarIntegrationEnabled) { _, enabled in
                        Task {
                            await appModel.updateCalendarIntegration(
                                enabled: enabled,
                                calendarID: calendarIntegrationCalendarID.nilIfEmpty
                            )
                            if calendarIntegration.permission != .authorized {
                                calendarIntegrationEnabled = false
                            }
                        }
                    }
                Picker("Calendar", selection: $calendarIntegrationCalendarID) {
                    Text("Default Calendar").tag("")
                    ForEach(calendarIntegration.calendars) { calendar in
                        Text("\(calendar.title) — \(calendar.sourceTitle)").tag(calendar.id)
                    }
                }
                .disabled(!calendarIntegrationEnabled)
                .onChange(of: calendarIntegrationCalendarID) { _, id in
                    guard calendarIntegrationEnabled else { return }
                    Task { await appModel.updateCalendarIntegration(enabled: true, calendarID: id.nilIfEmpty) }
                }
                Button("Create ClassSync Calendar") {
                    if let id = calendarIntegration.createClassSyncCalendar() {
                        calendarIntegrationCalendarID = id
                    }
                }
                .disabled(!calendarIntegrationEnabled || calendarIntegration.permission != .authorized)
                Toggle("Remove events when assignments disappear", isOn: $removeCancelledCalendarEvents)
                    .disabled(!calendarIntegrationEnabled)
                    .onChange(of: removeCancelledCalendarEvents) { _, _ in
                        guard calendarIntegrationEnabled else { return }
                        Task {
                            await appModel.updateCalendarIntegration(
                                enabled: true,
                                calendarID: calendarIntegrationCalendarID.nilIfEmpty
                            )
                        }
                    }
                LabeledContent("Permission", value: calendarPermissionDescription)
                if let message = calendarIntegration.errorMessage {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Account") {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Provider", value: appModel.providerName)
                        Text(accountStatusDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Sign in with Western") {
                        // Enabled only after Western approves the OAuth registration and
                        // the authorization-code exchange can be completed without
                        // embedding a client secret in the app.
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    .help("Waiting for Western to approve ClassSync's OAuth registration")
                    .accessibilityHint("Unavailable until Western approves the ClassSync OAuth registration")
                }

                Label(
                    "Your password and MFA are entered only on Western's official sign-in page. ClassSync never receives or stores them.",
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("Course, assignment, change-history, and sync data stays in ClassSync's sandbox on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Delete Local ClassSync Data", role: .destructive) {
                    confirmsDataDeletion = true
                }
                if let message = appModel.dataDeletionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(
            isPresented: $showsSyllabusPicker,
            allowedContentTypes: Self.syllabusDocumentTypes,
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                syllabusReview = try appModel.loadSyllabus(at: url)
                syllabusPickerMessage = nil
                showsSyllabusReview = true
            } catch {
                syllabusPickerMessage = (error as? LocalizedError)?.errorDescription ?? "The syllabus could not be opened."
            }
        }
        .sheet(isPresented: $showsSyllabusReview) {
            if let review = syllabusReview {
                SyllabusReviewView(initialResult: review) { approved in
                    appModel.importSyllabus(approved)
                    showsSyllabusReview = false
                }
            }
        }
        .sheet(isPresented: $showsEmailReview) {
            EmailSuggestionReviewView(appModel: appModel)
        }
        .confirmationDialog(
            "Delete local ClassSync data?",
            isPresented: $confirmsDataDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete Local Data", role: .destructive) {
                calendarIntegrationEnabled = false
                appModel.deleteLocalData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes local courses, assignments, change history, sync timestamps, reviewed-email identifiers, the saved private feed URL, reminders, and ClassSync-created calendar events. It does not change anything in Brightspace or Apple Mail.")
        }
        .confirmationDialog(
            "Remove imported syllabus?",
            isPresented: Binding(
                get: { syllabusCoursePendingRemoval != nil },
                set: { if !$0 { syllabusCoursePendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let course = syllabusCoursePendingRemoval {
                Button("Remove \(course.code)", role: .destructive) {
                    appModel.removeImportedSyllabusCourse(course)
                    syllabusCoursePendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) { syllabusCoursePendingRemoval = nil }
        } message: {
            Text("This removes only assignments imported from this syllabus. Brightspace calendar-feed data and other courses are unchanged.")
        }
    }

    private var permissionDescription: String {
        switch appModel.notificationPermission {
        case .notDetermined: "Not requested"
        case .denied: "Disabled in System Settings"
        case .authorized: "Enabled"
        }
    }

    private func refreshReminders() {
        Task { await appModel.refreshReminderSchedule() }
    }

    private var calendarPermissionDescription: String {
        switch calendarIntegration.permission {
        case .notDetermined: "Not requested"
        case .denied: "Disabled in System Settings"
        case .authorized: "Enabled"
        }
    }

    private var accountStatusDescription: String {
        if appModel.isUsingMockProvider {
            return "Offline sample data is active. Western sign-in is waiting for OAuth approval."
        }
        return "Western sign-in is waiting for an approved OAuth client ID, redirect URI, and secure code-exchange design."
    }

    private static var syllabusDocumentTypes: [UTType] {
        var values: [UTType] = [.pdf, .plainText, .rtf]
        if let doc = UTType(filenameExtension: "doc") { values.append(doc) }
        if let docx = UTType(filenameExtension: "docx") { values.append(docx) }
        return values
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private struct SyllabusReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var result: SyllabusImportResult
    let onImport: (SyllabusImportResult) -> Void

    init(initialResult: SyllabusImportResult, onImport: @escaping (SyllabusImportResult) -> Void) {
        _result = State(initialValue: initialResult)
        self.onImport = onImport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Syllabus Import").font(.title2.bold())
            Text("Nothing is saved until you approve this list.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(result.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if result.drafts.contains(where: { $0.dueDate < Date() }) {
                HStack {
                    Button("Move Past Dates Forward") { movePastDatesForward() }
                        .help("Advances each past date by whole years until it is no longer in the past.")
                    Button("Deselect Past Dates") { deselectPastDates() }
                    Spacer()
                }
            }

            Form {
                TextField("Course code", text: $result.courseCode)
                TextField("Course name", text: $result.courseName)
                ForEach($result.drafts) { $draft in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $draft.isSelected) {
                            TextField("Assignment title", text: $draft.title)
                        }
                        DatePicker(
                            "Due",
                            selection: $draft.dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .disabled(!draft.isSelected)
                        if draft.dueDate < Date() {
                            Label("This date is in the past", systemImage: "clock.badge.exclamationmark")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Import Selected") { onImport(result) }
                    .buttonStyle(.borderedProminent)
                    .disabled(result.drafts.allSatisfy { !$0.isSelected })
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
    }

    private func movePastDatesForward() {
        let now = Date()
        for index in result.drafts.indices where result.drafts[index].dueDate < now {
            var adjusted = result.drafts[index].dueDate
            while adjusted < now {
                guard let next = Calendar.current.date(byAdding: .year, value: 1, to: adjusted) else { break }
                adjusted = next
            }
            result.drafts[index].dueDate = adjusted
        }
        result.warnings.removeAll { $0.localizedCaseInsensitiveContains("well in the past") }
    }

    private func deselectPastDates() {
        let now = Date()
        for index in result.drafts.indices where result.drafts[index].dueDate < now {
            result.drafts[index].isSelected = false
        }
    }
}

private struct EmailSuggestionReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Email Suggestions").font(.title2.bold())
            Text("Email never changes a deadline until you approve it here.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appModel.emailSuggestions.isEmpty {
                ContentUnavailableView(
                    "No Suggestions",
                    systemImage: "checkmark.circle",
                    description: Text("All detected messages have been reviewed.")
                )
            } else {
                List(appModel.emailSuggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(suggestion.courseCode) · \(suggestion.assignmentTitle)")
                            .font(.headline)
                        HStack {
                            Text(suggestion.previousDueDate?.formatted(date: .abbreviated, time: .shortened) ?? "No previous date")
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                            Text(suggestion.proposedDueDate.formatted(date: .abbreviated, time: .shortened))
                                .fontWeight(.semibold)
                        }
                        Text("\(suggestion.emailSubject) — \(suggestion.sender)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack {
                            Button("Dismiss") { appModel.dismissEmailSuggestion(suggestion) }
                            Button("Apply Change") {
                                Task { await appModel.applyEmailSuggestion(suggestion) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 650, minHeight: 480)
    }
}
