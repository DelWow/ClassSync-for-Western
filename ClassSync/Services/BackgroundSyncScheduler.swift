import Foundation

@MainActor
protocol BackgroundSyncScheduling: AnyObject {
    var isScheduled: Bool { get }
    func schedule(interval: TimeInterval, operation: @escaping @MainActor () async -> Void)
    func cancel()
}

@MainActor
final class MacBackgroundSyncScheduler: BackgroundSyncScheduling {
    private var scheduler: NSBackgroundActivityScheduler?
    private(set) var isScheduled = false

    func schedule(interval: TimeInterval, operation: @escaping @MainActor () async -> Void) {
        cancel()

        let activity = NSBackgroundActivityScheduler(identifier: "com.annasamar.ClassSync.assignment-refresh")
        activity.repeats = true
        activity.interval = max(interval, 10 * 60)
        activity.tolerance = max(60, activity.interval * 0.2)
        activity.qualityOfService = .utility
        let activityBox = BackgroundActivityBox(activity)
        activity.schedule { completion in
            if activityBox.activity.shouldDefer {
                completion(.deferred)
                return
            }

            Task { @MainActor in
                await operation()
                completion(.finished)
            }
        }

        scheduler = activity
        isScheduled = true
    }

    func cancel() {
        scheduler?.invalidate()
        scheduler = nil
        isScheduled = false
    }
}

private final class BackgroundActivityBox: @unchecked Sendable {
    let activity: NSBackgroundActivityScheduler

    init(_ activity: NSBackgroundActivityScheduler) {
        self.activity = activity
    }
}
