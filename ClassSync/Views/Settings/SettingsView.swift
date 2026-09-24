import SwiftUI

struct SettingsView: View {
    let courses: [Course]

    var body: some View {
        SettingsContentView(courses: courses)
            .frame(width: 560, height: 520)
    }
}

struct SettingsContentView: View {
    let courses: [Course]

    @AppStorage("automaticallySync") private var automaticallySync = true
    @AppStorage("syncIntervalMinutes") private var syncIntervalMinutes = 60
    @AppStorage("notifyNewAssignments") private var notifyNewAssignments = true
    @AppStorage("notifyDueDateChanges") private var notifyDueDateChanges = true
    @AppStorage("notifyRemovedAssignments") private var notifyRemovedAssignments = false
    @AppStorage("remind24Hours") private var remind24Hours = true
    @AppStorage("remind6Hours") private var remind6Hours = true
    @AppStorage("remind1Hour") private var remind1Hour = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Automatically sync", isOn: $automaticallySync)
                Toggle("Launch at Login", isOn: .constant(false))
                    .disabled(true)
                Text("Launch at Login will be enabled after supported system registration is implemented.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sync") {
                Picker("Frequency", selection: $syncIntervalMinutes) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("Manual only").tag(0)
                }
                .disabled(!automaticallySync)
                Text("macOS may delay background work to preserve battery life.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("New assignments", isOn: $notifyNewAssignments)
                Toggle("Due-date changes", isOn: $notifyDueDateChanges)
                Toggle("Removed assignments", isOn: $notifyRemovedAssignments)
                Toggle("24-hour reminders", isOn: $remind24Hours)
                Toggle("6-hour reminders", isOn: $remind6Hours)
                Toggle("1-hour reminders", isOn: $remind1Hour)
            }

            Section("Courses") {
                if courses.isEmpty {
                    Text("No courses available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(courses) { course in
                        LabeledContent(course.code, value: course.name)
                    }
                }
            }

            Section("Account") {
                LabeledContent("Provider", value: "Mock Brightspace")
                Text("Production Brightspace authentication is not connected yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
