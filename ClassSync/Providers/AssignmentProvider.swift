import Foundation

struct ProviderCapabilities: OptionSet, Sendable {
    let rawValue: Int

    static let courses = ProviderCapabilities(rawValue: 1 << 0)
    static let assignments = ProviderCapabilities(rawValue: 1 << 1)
    static let submissionStatus = ProviderCapabilities(rawValue: 1 << 2)
}

enum ProviderError: LocalizedError, Equatable {
    case notAuthenticated
    case authenticationExpired
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Connect your account before syncing."
        case .authenticationExpired:
            "Your session expired. Reconnect your account and try again."
        case .unavailable:
            "The assignment provider is temporarily unavailable."
        case .invalidResponse:
            "The provider returned data that ClassSync could not understand."
        }
    }
}

protocol AssignmentProvider: Sendable {
    var id: String { get }
    var name: String { get }
    var capabilities: ProviderCapabilities { get }

    func authenticate() async throws
    func fetchCourses() async throws -> [Course]
    func fetchAssignments() async throws -> [Assignment]
}

struct MockAssignmentProvider: AssignmentProvider {
    let id = "mock-brightspace"
    let name = "Mock Brightspace"
    let capabilities: ProviderCapabilities = [.courses, .assignments, .submissionStatus]

    func authenticate() async throws {}

    func fetchCourses() async throws -> [Course] {
        MockData.courses
    }

    func fetchAssignments() async throws -> [Assignment] {
        MockData.assignments
    }
}

