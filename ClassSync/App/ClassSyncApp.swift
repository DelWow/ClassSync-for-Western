import SwiftUI

@main
struct ClassSyncApp: App {
    @State private var lastSyncedAt: Date?

    var body: some Scene {
        MenuBarExtra("ClassSync", systemImage: "calendar.badge.clock") {
            MenuBarView(
                assignments: MockAssignment.upcoming,
                lastSyncedAt: $lastSyncedAt
            )
        }
        .menuBarExtraStyle(.window)

        Window("ClassSync Dashboard", id: "dashboard") {
            DashboardView(assignments: MockAssignment.upcoming)
        }
        .defaultSize(width: 720, height: 480)

        Settings {
            SettingsView()
        }
    }
}

