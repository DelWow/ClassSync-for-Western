import Foundation

actor BrightspaceProvider: AssignmentProvider {
    nonisolated let id = "brightspace-western"
    nonisolated let name = "Western Brightspace"
    nonisolated let capabilities: ProviderCapabilities = [.courses, .assignments, .submissionStatus]

    private let client: any BrightspaceClientProtocol
    private let tokenProvider: any BrightspaceAccessTokenProviding
    private let mapper: BrightspaceMapper
    private let calendar: Calendar

    init(
        client: any BrightspaceClientProtocol,
        tokenProvider: any BrightspaceAccessTokenProviding,
        mapper: BrightspaceMapper = BrightspaceMapper(),
        calendar: Calendar = .current
    ) {
        self.client = client
        self.tokenProvider = tokenProvider
        self.mapper = mapper
        self.calendar = calendar
    }

    func authenticate() async throws {
        _ = try await tokenProvider.accessToken()
    }

    func fetchCourses() async throws -> [Course] {
        try await client.fetchActiveEnrollments()
            .compactMap(mapper.course(from:))
            .filter(\.isActive)
            .sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending }
    }

    func fetchAssignments() async throws -> [Assignment] {
        let courses = try await fetchCourses()
        let now = Date()
        let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        let end = calendar.date(byAdding: .year, value: 2, to: now) ?? now
        var assignments: [Assignment] = []

        for course in courses {
            guard let courseID = Int(course.externalID) else { continue }
            async let eventsRequest = client.fetchDueDateEvents(courseID: courseID, start: start, end: end)
            async let foldersRequest = client.fetchDropboxFolders(courseID: courseID)
            let (events, folders) = try await (eventsRequest, foldersRequest)

            let dropboxIDs = Set(folders.map(\.id))
            assignments.append(contentsOf: events.compactMap { event in
                if let folderID = mapper.dropboxFolderID(from: event), dropboxIDs.contains(folderID) {
                    return nil
                }
                return mapper.assignment(from: event, course: course)
            })

            for folder in folders {
                let submissions = try await client.fetchMySubmissions(courseID: courseID, folderID: folder.id)
                let isSubmitted = submissions.contains { !$0.submissions.isEmpty || $0.status == "1" }
                if let assignment = mapper.assignment(from: folder, course: course, submitted: isSubmitted) {
                    assignments.append(assignment)
                }
            }
        }

        return assignments
            .uniquedByID()
            .sorted(by: Assignment.dueDateAscending)
    }
}

private extension Sequence where Element == Assignment {
    func uniquedByID() -> [Assignment] {
        var seen: Set<String> = []
        return filter { seen.insert($0.id).inserted }
    }
}
