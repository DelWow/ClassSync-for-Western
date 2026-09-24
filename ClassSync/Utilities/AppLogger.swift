import Foundation
import OSLog

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.annasamar.ClassSync"

    static let authentication = Logger(subsystem: subsystem, category: "Authentication")
    static let sync = Logger(subsystem: subsystem, category: "Sync")
    static let database = Logger(subsystem: subsystem, category: "Database")
    static let notifications = Logger(subsystem: subsystem, category: "Notifications")
    static let brightspace = Logger(subsystem: subsystem, category: "Brightspace")
    static let browser = Logger(subsystem: subsystem, category: "Browser")
}
