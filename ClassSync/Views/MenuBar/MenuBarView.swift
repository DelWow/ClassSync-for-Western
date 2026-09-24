import AppKit
import SwiftUI

struct MenuBarView: View {
    let assignments: [MockAssignment]
    @Binding var lastSyncedAt: Date?

    @Environment(\.openWindow) private var openWindow
    @State private var isSyncing = false

    private var calendar: Calendar { .current }

    private var dueToday: [MockAssignment] {
        assignments.filter { calendar.isDateInToday($0.dueDate) }
    }

    private var dueTomorrow: [MockAssignment] {
        assignments.filter { calendar.isDateInTomorrow($0.dueDate) }
    }

    private var dueThisWeek: [MockAssignment] {
        assignments.filter {
            !calendar.isDateInToday($0.dueDate)
                && !calendar.isDateInTomorrow($0.dueDate)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ClassSync", systemImage: "calendar.badge.clock")
                .font(.headline)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    assignmentSection(title: "Today", assignments: dueToday)
                    assignmentSection(title: "Tomorrow", assignments: dueTomorrow)
                    assignmentSection(title: "This Week", assignments: dueThisWeek)
                }
            }
            .frame(maxHeight: 300)

            Divider()

            HStack {
                Text("\(assignments.count) upcoming")
                Spacer()
                Text(lastSyncedDescription)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button(action: syncNow) {
                HStack {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }

                    Text(isSyncing ? "Syncing…" : "Sync Now")
                    Spacer()
                }
            }
            .disabled(isSyncing)

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
        .frame(width: 360)
    }

    @ViewBuilder
    private func assignmentSection(
        title: String,
        assignments: [MockAssignment]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if assignments.isEmpty {
                Text("No assignments due \(title.lowercased()).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignments) { assignment in
                    AssignmentRow(assignment: assignment)
                }
            }
        }
    }

    private var lastSyncedDescription: String {
        guard let lastSyncedAt else {
            return "Last synced: Never"
        }

        return "Last synced: \(lastSyncedAt.formatted(date: .omitted, time: .shortened))"
    }

    private func syncNow() {
        isSyncing = true

        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            lastSyncedAt = Date()
            isSyncing = false
        }
    }
}

