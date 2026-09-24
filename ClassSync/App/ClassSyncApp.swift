import SwiftData
import SwiftUI

@main
struct ClassSyncApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appModel: AppModel

    @MainActor
    init() {
        let persistence = PersistenceController.shared
        let store = SwiftDataAssignmentStore(container: persistence.container)
        modelContainer = persistence.container
        _appModel = StateObject(
            wrappedValue: AppModel(
                provider: MockAssignmentProvider(),
                store: store
            )
        )
    }

    var body: some Scene {
        MenuBarExtra("ClassSync", systemImage: "calendar.badge.clock") {
            MenuBarView(appModel: appModel)
                .task { appModel.load() }
        }
        .menuBarExtraStyle(.window)

        Window("ClassSync Dashboard", id: "dashboard") {
            DashboardView(appModel: appModel)
                .task { appModel.load() }
        }
        .defaultSize(width: 720, height: 480)

        Settings {
            SettingsView(courses: appModel.courses)
                .task { appModel.load() }
        }
    }
}
