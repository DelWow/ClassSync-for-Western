import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appModel: AppModel

    @Environment(\.openWindow) private var openWindow

    private var calendar: Calendar { .current }

    private var overdue: [Assignment] {
        appModel.visibleAssignments.filter(\.isOverdue)
    }

    private var dueToday: [Assignment] {
        appModel.visibleAssignments.filter {
            !$0.isOverdue && $0.dueDate.map(calendar.isDateInToday) == true
        }
    }

    private var dueTomorrow: [Assignment] {
        appModel.visibleAssignments.filter {
            !$0.isOverdue && $0.dueDate.map(calendar.isDateInTomorrow) == true
        }
    }

    private var dueThisWeek: [Assignment] {
        appModel.visibleAssignments.filter { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return !assignment.isOverdue
                && !calendar.isDateInToday(dueDate)
                && !calendar.isDateInTomorrow(dueDate)
        }
    }

    private var withoutDueDate: [Assignment] {
        appModel.visibleAssignments.filter { $0.dueDate == nil }
    }

    private var upcomingCount: Int {
        appModel.visibleAssignments.filter { !$0.isOverdue && $0.status != .submitted && $0.dueDate != nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ClassSync", systemImage: "calendar.badge.clock")
                .font(.headline)

            if let persistenceMessage = appModel.persistenceMessage {
                Label(persistenceMessage, systemImage: "externaldrive.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if case let .failed(message) = appModel.syncState {
                Label(message, systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !overdue.isEmpty {
                        assignmentSection(title: "Overdue", assignments: overdue)
                    }
                    assignmentSection(title: "Today", assignments: dueToday)
                    assignmentSection(title: "Tomorrow", assignments: dueTomorrow)
                    assignmentSection(title: "This Week", assignments: dueThisWeek)
                    assignmentSection(title: "No Due Date", assignments: withoutDueDate)
                }
            }
            .frame(maxHeight: 390)

            Divider()

            HStack {
                Text("\(upcomingCount) upcoming")
                Spacer()
                Text(lastSyncedDescription)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button {
                Task { await appModel.syncNow() }
            } label: {
                HStack {
                    if appModel.syncState == .syncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }

                    Text(appModel.syncState == .syncing ? "Syncing…" : "Sync Now")
                    Spacer()
                }
            }
            .disabled(appModel.syncState == .syncing)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            } label: {
                Label("Open Dashboard", systemImage: "rectangle.grid.1x2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
            })

            Divider()

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit ClassSync", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.bordered)
        .padding(16)
        .frame(width: 380)
    }

    @ViewBuilder
    private func assignmentSection(title: String, assignments: [Assignment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if assignments.isEmpty {
                Text(emptyMessage(for: title))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignments) { assignment in
                    AssignmentRow(
                        assignment: assignment,
                        courseColorHex: appModel.colorHex(for: assignment.courseID)
                    )
                }
            }
        }
    }

    private func emptyMessage(for title: String) -> String {
        title == "No Due Date" ? "Every assignment has a due date." : "No assignments due \(title.lowercased())."
    }

    private var lastSyncedDescription: String {
        guard let lastSyncedAt = appModel.lastSyncedAt else {
            return "Last synced: Never"
        }
        return "Last synced: \(lastSyncedAt.formatted(date: .omitted, time: .shortened))"
    }
}
