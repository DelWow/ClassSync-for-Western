import SwiftData
import SwiftUI

@main
struct ClassSyncApp: App {
    @NSApplicationDelegateAdaptor(NotificationAppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @StateObject private var appModel: AppModel

    @MainActor
    init() {
        let persistence = PersistenceController.shared
        let store = SwiftDataAssignmentStore(container: persistence.container)
        #if DEBUG
        let provider: any AssignmentProvider = MockAssignmentProvider()
        #else
        // A release build must never silently present fixture data as real LMS data.
        // This provider remains unavailable until an approved OAuth registration is configured.
        let provider: any AssignmentProvider = ProductionConfigurationRequiredProvider()
        #endif
        modelContainer = persistence.container
        _appModel = StateObject(
            wrappedValue: AppModel(
                provider: provider,
                store: store,
                notificationService: NotificationService(),
                backgroundScheduler: MacBackgroundSyncScheduler(),
                calendarIntegration: CalendarIntegrationService()
            )
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appModel: appModel)
                .task { appModel.load() }
        } label: {
            MenuBarStatusLabel(appModel: appModel)
        }
        .menuBarExtraStyle(.window)

        Window("ClassSync Dashboard", id: "dashboard") {
            DashboardView(appModel: appModel)
                .task { appModel.load() }
        }
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView(appModel: appModel)
                .task { appModel.load() }
        }
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var appModel: AppModel
    @AppStorage("showDueTodayCount") private var showDueTodayCount = true

    private var dueToday: [Assignment] {
        appModel.visibleAssignments.filter { assignment in
            assignment.status != .submitted
                && assignment.dueDate.map(Calendar.current.isDateInToday) == true
        }
    }

    private var isDueSoon: Bool {
        let now = Date()
        let threshold = now.addingTimeInterval(6 * 60 * 60)
        return dueToday.contains { assignment in
            guard let dueDate = assignment.dueDate else { return false }
            return dueDate > now && dueDate <= threshold
        }
    }

    private var systemImage: String {
        if case .failed = appModel.syncState { return "exclamationmark.triangle.fill" }
        if isDueSoon { return "exclamationmark.circle.fill" }
        if appModel.visibleAssignments.isEmpty { return "checkmark.circle" }
        return "calendar.badge.clock"
    }

    private var accessibleStatus: String {
        if case .failed = appModel.syncState { return "ClassSync, synchronization problem" }
        if isDueSoon { return "ClassSync, assignment due within six hours" }
        if dueToday.isEmpty { return "ClassSync, no assignments due today" }
        return "ClassSync, \(dueToday.count) assignments due today"
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
            if showDueTodayCount && !dueToday.isEmpty {
                Text("\(dueToday.count)")
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(accessibleStatus)
    }
}
