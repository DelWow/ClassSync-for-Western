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
    case networkUnavailable
    case forbidden
    case rateLimited
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Connect your account before syncing."
        case .authenticationExpired:
            "Your session expired. Reconnect your account and try again."
        case .networkUnavailable:
            "Could not connect to Brightspace. Check your internet connection and try again."
        case .forbidden:
            "Brightspace did not grant access to the requested course data."
        case .rateLimited:
            "Brightspace is receiving too many requests. Wait a moment and try again."
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
    var managedSources: Set<AssignmentSource> { get }

    func authenticate() async throws
    func fetchCourses() async throws -> [Course]
    func fetchAssignments() async throws -> [Assignment]
}

extension AssignmentProvider {
    var managedSources: Set<AssignmentSource> { Set(AssignmentSource.allCases) }
}

struct MockAssignmentProvider: AssignmentProvider {
    let id = "mock-brightspace"
    let name = "Mock Brightspace"
    let capabilities: ProviderCapabilities = [.courses, .assignments, .submissionStatus]
    let managedSources: Set<AssignmentSource> = [.brightspace]

    func authenticate() async throws {}

    func fetchCourses() async throws -> [Course] {
        MockData.courses
    }

    func fetchAssignments() async throws -> [Assignment] {
        MockData.assignments
    }
}

struct ProductionConfigurationRequiredProvider: AssignmentProvider {
    let id = "brightspace-western"
    let name = "Western Brightspace"
    let capabilities: ProviderCapabilities = [.courses, .assignments, .submissionStatus]
    let managedSources: Set<AssignmentSource> = [.brightspace]

    func authenticate() async throws { throw ProviderError.notAuthenticated }
    func fetchCourses() async throws -> [Course] { throw ProviderError.notAuthenticated }
    func fetchAssignments() async throws -> [Assignment] { throw ProviderError.notAuthenticated }
}

struct CompositeAssignmentProvider: AssignmentProvider {
    let id: String
    let name: String
    let providers: [any AssignmentProvider]

    var capabilities: ProviderCapabilities {
        providers.reduce([]) { $0.union($1.capabilities) }
    }

    var managedSources: Set<AssignmentSource> {
        providers.reduce(into: Set<AssignmentSource>()) { result, provider in
            result.formUnion(provider.managedSources)
        }
    }

    init(id: String = "connected-sources", name: String = "Connected Sources", providers: [any AssignmentProvider]) {
        self.id = id
        self.name = name
        self.providers = providers
    }

    func authenticate() async throws {
        for provider in providers { try await provider.authenticate() }
    }

    func fetchCourses() async throws -> [Course] {
        var values: [String: Course] = [:]
        for provider in providers {
            for course in try await provider.fetchCourses() { values[course.id] = course }
        }
        return values.values.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    func fetchAssignments() async throws -> [Assignment] {
        var values: [String: Assignment] = [:]
        for provider in providers {
            for assignment in try await provider.fetchAssignments() { values[assignment.id] = assignment }
        }
        return values.values.sorted(by: Assignment.dueDateAscending)
    }
}
