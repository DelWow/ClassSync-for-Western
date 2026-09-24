import Foundation
import ServiceManagement

enum LaunchAtLoginState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
    case failed(String)
}

protocol LoginItemClient {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func openSystemSettings()
}

struct SystemLoginItemClient: LoginItemClient {
    private let service = SMAppService.mainApp

    var status: SMAppService.Status { service.status }
    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var state: LaunchAtLoginState = .disabled
    private let client: any LoginItemClient

    init(client: any LoginItemClient = SystemLoginItemClient()) {
        self.client = client
        refresh()
    }

    func refresh() {
        switch client.status {
        case .enabled:
            state = .enabled
        case .requiresApproval:
            state = .requiresApproval
        case .notRegistered:
            state = .disabled
        case .notFound:
            state = .unavailable
        @unknown default:
            state = .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try client.register()
            } else {
                try client.unregister()
            }
            refresh()
        } catch {
            state = .failed("Could not update Launch at Login. Review Login Items in System Settings.")
            AppLogger.authentication.error("Launch at Login update failed")
        }
    }

    func openSystemSettings() {
        client.openSystemSettings()
    }
}

