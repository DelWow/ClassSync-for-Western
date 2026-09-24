import Foundation

enum AppError: LocalizedError, Equatable {
    case networkUnavailable
    case authenticationExpired
    case providerUnavailable
    case persistenceUnavailable
    case notificationPermissionDenied
    case calendarPermissionDenied
    case invalidAssignmentURL

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            "Could not connect. Check your internet connection and try again."
        case .authenticationExpired:
            "Your Brightspace session expired. Reconnect your account and try again."
        case .providerUnavailable:
            "Brightspace is temporarily unavailable. Try again later."
        case .persistenceUnavailable:
            "Local data could not be saved. Restart ClassSync and try again."
        case .notificationPermissionDenied:
            "Notifications are disabled. Enable them for ClassSync in System Settings."
        case .calendarPermissionDenied:
            "Calendar access is disabled. Enable it for ClassSync in System Settings."
        case .invalidAssignmentURL:
            "This assignment does not have a valid page to open."
        }
    }
}

