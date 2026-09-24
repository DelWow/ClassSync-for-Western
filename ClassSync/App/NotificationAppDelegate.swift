import AppKit
import UserNotifications

final class NotificationAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let userInfo = response.notification.request.content.userInfo
        guard
            let rawURL = userInfo["url"] as? String,
            let url = URL(string: rawURL),
            let rawSource = userInfo["source"] as? String,
            let source = AssignmentSource(rawValue: rawSource),
            let validatedURL = AssignmentURLValidator.validatedURL(url, source: source)
        else {
            return
        }
        Task { @MainActor in
            PreferredBrowserService.open(validatedURL)
        }
    }
}
