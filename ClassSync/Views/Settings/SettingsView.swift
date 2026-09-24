import SwiftUI

struct SettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SettingsContentView(appModel: appModel)
            .frame(width: 560, height: 520)
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
    @State private var confirmsDataDeletion = false

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
                if appModel.courses.isEmpty {
                    Text("No courses available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.courses) { course in
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
                LabeledContent("Provider", value: appModel.providerName)
                Text(appModel.isUsingMockProvider
                    ? "This Debug build uses offline fixture data."
                    : "Production Brightspace authentication requires approved OAuth registration before it can connect.")
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
            Text("This removes local courses, assignments, change history, sync timestamps, reminders, and ClassSync-created calendar events. It does not change anything in Brightspace.")
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
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
