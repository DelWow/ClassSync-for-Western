import ServiceManagement
import XCTest
@testable import ClassSync

@MainActor
final class SystemServiceTests: XCTestCase {
    func testBackgroundSchedulerConfigurationCanBeReplacedAndCancelled() {
        let scheduler = FakeBackgroundScheduler()
        scheduler.schedule(interval: 1_800) {}
        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.interval, 1_800)

        scheduler.schedule(interval: 3_600) {}
        XCTAssertEqual(scheduler.interval, 3_600)

        scheduler.cancel()
        XCTAssertFalse(scheduler.isScheduled)
    }

    func testLaunchAtLoginReflectsRegistrationState() {
        let client = FakeLoginItemClient(status: .notRegistered)
        let service = LaunchAtLoginService(client: client)
        XCTAssertEqual(service.state, .disabled)

        service.setEnabled(true)
        XCTAssertEqual(service.state, .enabled)

        service.setEnabled(false)
        XCTAssertEqual(service.state, .disabled)
    }

    func testLaunchAtLoginReportsApprovalRequirementAndErrors() {
        let approvalClient = FakeLoginItemClient(status: .requiresApproval)
        XCTAssertEqual(LaunchAtLoginService(client: approvalClient).state, .requiresApproval)

        let failingClient = FakeLoginItemClient(status: .notRegistered)
        failingClient.registerError = TestError.failed
        let service = LaunchAtLoginService(client: failingClient)
        service.setEnabled(true)
        guard case .failed = service.state else { return XCTFail("Expected failed state") }
    }

    func testPreferredBrowserChoosesChromeBeforeSafari() throws {
        let installedApplications = [
            "com.google.Chrome": URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            "com.apple.Safari": URL(fileURLWithPath: "/Applications/Safari.app")
        ]

        let browser = PreferredBrowserService.preferredBrowser {
            installedApplications[$0]
        }

        XCTAssertEqual(browser?.bundleIdentifier, "com.google.Chrome")
    }

    func testPreferredBrowserFallsBackToSafari() throws {
        let browser = PreferredBrowserService.preferredBrowser { bundleIdentifier in
            bundleIdentifier == "com.apple.Safari"
                ? URL(fileURLWithPath: "/Applications/Safari.app")
                : nil
        }

        XCTAssertEqual(browser?.bundleIdentifier, "com.apple.Safari")
    }
}

@MainActor
private final class FakeBackgroundScheduler: BackgroundSyncScheduling {
    var isScheduled = false
    var interval: TimeInterval?

    func schedule(interval: TimeInterval, operation: @escaping @MainActor () async -> Void) {
        self.interval = interval
        isScheduled = true
    }

    func cancel() {
        isScheduled = false
        interval = nil
    }
}

private final class FakeLoginItemClient: LoginItemClient {
    var status: SMAppService.Status
    var registerError: Error?
    var unregisterError: Error?

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }

    func openSystemSettings() {}
}

private enum TestError: Error {
    case failed
}
