import XCTest
@testable import ClassSync

final class BrightspaceProviderTests: XCTestCase {
    func testMockProviderSatisfiesSharedProviderContract() async throws {
        let provider: any AssignmentProvider = MockAssignmentProvider()
        try await provider.authenticate()
        let courses = try await provider.fetchCourses()
        let assignments = try await provider.fetchAssignments()

        XCTAssertTrue(provider.capabilities.contains([.courses, .assignments]))
        XCTAssertFalse(courses.isEmpty)
        XCTAssertFalse(assignments.isEmpty)
        XCTAssertTrue(courses.allSatisfy { $0.id == Course.stableID(source: $0.source, externalID: $0.externalID) })
        XCTAssertTrue(assignments.allSatisfy { $0.id == Assignment.stableID(source: $0.source, externalID: $0.externalID) })
    }

    func testCourseMapperAcceptsOnlyCourseOfferings() throws {
        let courseEnrollment = try decodeEnrollment(typeCode: "Course Offering")
        let semesterEnrollment = try decodeEnrollment(typeCode: "Semester")
        let mapper = BrightspaceMapper()

        let course = mapper.course(from: courseEnrollment)

        XCTAssertEqual(course?.id, "brightspace:12345")
        XCTAssertEqual(course?.code, "COMPSCI 1026A")
        XCTAssertEqual(course?.name, "Computer Science Fundamentals")
        XCTAssertTrue(course?.isActive == true)
        XCTAssertNil(mapper.course(from: semesterEnrollment))
    }

    func testCalendarMapperPreservesUTCInstantAndRelativeURL() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let mapper = BrightspaceMapper(now: { now })
        let event = try JSONDecoder().decode(BrightspaceCalendarEvent.self, from: Data(calendarEventJSON.utf8))
        let course = try XCTUnwrap(mapper.course(from: decodeEnrollment(typeCode: "Course Offering")))

        let assignment = try XCTUnwrap(mapper.assignment(from: event, course: course))

        XCTAssertEqual(assignment.externalID, "calendar:777")
        XCTAssertEqual(assignment.dueDate, ISO8601DateFormatter().date(from: "2026-10-12T03:00:00Z"))
        XCTAssertEqual(assignment.url?.absoluteString, "https://westernu.brightspace.com/d2l/le/calendar/777")
        XCTAssertEqual(assignment.status, .upcoming)
    }

    func testProviderCombinesCalendarAndDropboxWithoutDuplicatingLinkedFolder() async throws {
        let client = BrightspaceClientStub(
            enrollments: [try decodeEnrollment(typeCode: "Course Offering")],
            events: [
                try JSONDecoder().decode(BrightspaceCalendarEvent.self, from: Data(calendarEventJSON.utf8)),
                try JSONDecoder().decode(BrightspaceCalendarEvent.self, from: Data(dropboxCalendarEventJSON.utf8))
            ],
            folders: [try JSONDecoder().decode(BrightspaceDropboxFolder.self, from: Data(dropboxFolderJSON.utf8))],
            submissions: [try JSONDecoder().decode(BrightspaceEntityDropbox.self, from: Data(submissionJSON.utf8))]
        )
        let token = StaticTokenProvider(token: "fixture")
        let provider = BrightspaceProvider(client: client, tokenProvider: token)

        let courses = try await provider.fetchCourses()
        let assignments = try await provider.fetchAssignments()

        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(assignments.count, 2)
        XCTAssertEqual(Set(assignments.map(\.externalID)), ["calendar:777", "dropbox:55"])
        XCTAssertEqual(assignments.first { $0.externalID == "dropbox:55" }?.status, .submitted)
        XCTAssertTrue(assignments.allSatisfy { $0.id == Assignment.stableID(source: $0.source, externalID: $0.externalID) })
    }

    func testAuthorizationURLUsesOfficialEndpointAndReadOnlyScopes() async throws {
        let authentication = BrightspaceAuthentication()
        let registration = BrightspaceOAuthRegistration(
            clientID: "client-id",
            redirectURI: URL(string: "classsync://oauth/callback")!
        )

        let url = try await authentication.authorizationURL(registration: registration, state: "nonce")
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        XCTAssertEqual(url.host, "auth.brightspace.com")
        XCTAssertEqual(url.path, "/oauth2/auth")
        XCTAssertEqual(values["response_type"]!, "code")
        XCTAssertEqual(values["state"]!, "nonce")
        XCTAssertTrue(values["scope"]!!.contains("enrollment:own_enrollment:read"))
        XCTAssertFalse(values["scope"]!!.contains("write"))
    }
}

final class BrightspaceClientTests: XCTestCase {
    func testClientUsesBearerTokenAndExpectedEnrollmentRoute() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://westernu.brightspace.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let http = HTTPClientStub(data: Data(enrollmentPageJSON.utf8), response: response)
        let client = BrightspaceClient(tokenProvider: StaticTokenProvider(token: "secret-fixture"), httpClient: http)

        let enrollments = try await client.fetchActiveEnrollments()
        let capturedRequest = await http.lastRequest
        let request = try XCTUnwrap(capturedRequest)

        XCTAssertEqual(enrollments.count, 1)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-fixture")
        XCTAssertTrue(request.url?.path.contains("/d2l/api/lp/1.49/enrollments/myenrollments/") == true)
        XCTAssertTrue(request.url?.query?.contains("isActive=true") == true)
    }

    func testClientMapsUnauthorizedResponseToExpiredAuthentication() async {
        let response = HTTPURLResponse(
            url: URL(string: "https://westernu.brightspace.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let client = BrightspaceClient(
            tokenProvider: StaticTokenProvider(token: "fixture"),
            httpClient: HTTPClientStub(data: Data(), response: response)
        )

        do {
            _ = try await client.fetchActiveEnrollments()
            XCTFail("Expected authentication expiration")
        } catch {
            XCTAssertEqual(error as? ProviderError, .authenticationExpired)
        }
    }

    func testClientFollowsEnrollmentBookmarks() async throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://westernu.brightspace.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let first = enrollmentPageJSON.replacingOccurrences(
            of: #""HasMoreItems": false"#,
            with: #""HasMoreItems": true"#
        )
        let http = SequenceHTTPClientStub(responses: [
            (Data(first.utf8), response),
            (Data(enrollmentPageJSON.utf8), response)
        ])
        let client = BrightspaceClient(tokenProvider: StaticTokenProvider(token: "fixture"), httpClient: http)

        let enrollments = try await client.fetchActiveEnrollments()
        let requests = await http.requests

        XCTAssertEqual(enrollments.count, 2)
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests[1].url?.query?.contains("bookmark=12345") == true)
    }

    func testClientMapsMalformedAndTemporaryFailures() async {
        let ok = HTTPURLResponse(
            url: URL(string: "https://westernu.brightspace.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let malformed = BrightspaceClient(
            tokenProvider: StaticTokenProvider(token: "fixture"),
            httpClient: HTTPClientStub(data: Data(#"{"unexpected":true}"#.utf8), response: ok),
            retryPolicy: .disabled
        )
        await assertProviderError(.invalidResponse) {
            _ = try await malformed.fetchActiveEnrollments()
        }

        for (status, expected) in [(429, ProviderError.rateLimited), (503, ProviderError.unavailable)] {
            let response = HTTPURLResponse(
                url: URL(string: "https://westernu.brightspace.com")!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!
            let client = BrightspaceClient(
                tokenProvider: StaticTokenProvider(token: "fixture"),
                httpClient: HTTPClientStub(data: Data(), response: response),
                retryPolicy: .disabled
            )
            await assertProviderError(expected) {
                _ = try await client.fetchActiveEnrollments()
            }
        }
    }

    func testClientRetriesTemporaryFailureThenSucceeds() async throws {
        let unavailable = HTTPURLResponse(
            url: URL(string: "https://westernu.brightspace.com")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: ["Retry-After": "0"]
        )!
        let ok = HTTPURLResponse(
            url: URL(string: "https://westernu.brightspace.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        let http = SequenceHTTPClientStub(responses: [
            (Data(), unavailable),
            (Data(enrollmentPageJSON.utf8), ok)
        ])
        let client = BrightspaceClient(
            tokenProvider: StaticTokenProvider(token: "fixture"),
            httpClient: http,
            sleep: { _ in }
        )

        let enrollments = try await client.fetchActiveEnrollments()
        let requestCount = await http.requests.count

        XCTAssertEqual(enrollments.count, 1)
        XCTAssertEqual(requestCount, 2)
    }

    func testRetryPolicyNeverRetriesAuthenticationOrPermissionFailures() {
        let policy = BrightspaceRetryPolicy.standard
        XCTAssertNil(policy.delay(statusCode: 401, attempt: 1, retryAfter: nil))
        XCTAssertNil(policy.delay(statusCode: 403, attempt: 1, retryAfter: nil))
        XCTAssertNotNil(policy.delay(statusCode: 429, attempt: 1, retryAfter: "0"))
        XCTAssertNil(policy.delay(statusCode: 503, attempt: 3, retryAfter: nil))
    }

    private func assertProviderError(
        _ expected: ProviderError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch {
            XCTAssertEqual(error as? ProviderError, expected)
        }
    }
}

private struct StaticTokenProvider: BrightspaceAccessTokenProviding {
    let token: String
    func accessToken() async throws -> String { token }
}

private actor HTTPClientStub: BrightspaceHTTPClient {
    let data: Data
    let response: URLResponse
    private(set) var lastRequest: URLRequest?

    init(data: Data, response: URLResponse) {
        self.data = data
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        return (data, response)
    }
}

private actor SequenceHTTPClientStub: BrightspaceHTTPClient {
    private var responses: [(Data, URLResponse)]
    private(set) var requests: [URLRequest] = []

    init(responses: [(Data, URLResponse)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }
}

private actor BrightspaceClientStub: BrightspaceClientProtocol {
    let enrollments: [BrightspaceEnrollment]
    let events: [BrightspaceCalendarEvent]
    let folders: [BrightspaceDropboxFolder]
    let submissions: [BrightspaceEntityDropbox]

    init(
        enrollments: [BrightspaceEnrollment],
        events: [BrightspaceCalendarEvent],
        folders: [BrightspaceDropboxFolder],
        submissions: [BrightspaceEntityDropbox]
    ) {
        self.enrollments = enrollments
        self.events = events
        self.folders = folders
        self.submissions = submissions
    }

    func fetchActiveEnrollments() async throws -> [BrightspaceEnrollment] { enrollments }
    func fetchDueDateEvents(courseID: Int, start: Date, end: Date) async throws -> [BrightspaceCalendarEvent] { events }
    func fetchDropboxFolders(courseID: Int) async throws -> [BrightspaceDropboxFolder] { folders }
    func fetchMySubmissions(courseID: Int, folderID: Int) async throws -> [BrightspaceEntityDropbox] { submissions }
}

private func decodeEnrollment(typeCode: String) throws -> BrightspaceEnrollment {
    let json = enrollmentJSON.replacingOccurrences(of: "TYPE_CODE", with: typeCode)
    return try JSONDecoder().decode(BrightspaceEnrollment.self, from: Data(json.utf8))
}

private let enrollmentJSON = #"""
{
  "OrgUnit": {
    "Id": 12345,
    "Type": { "Id": 3, "Code": "TYPE_CODE", "Name": "TYPE_CODE" },
    "Name": "Computer Science Fundamentals",
    "Code": "COMPSCI 1026A",
    "HomeUrl": "/d2l/home/12345"
  },
  "Access": {
    "IsActive": true,
    "CanAccess": true,
    "StartDate": "2026-09-01T00:00:00.000Z",
    "EndDate": "2026-12-31T23:59:59.000Z"
  }
}
"""#

private let enrollmentPageJSON = #"""
{
  "PagingInfo": { "Bookmark": "12345", "HasMoreItems": false },
  "Items": [
    {
      "OrgUnit": {
        "Id": 12345,
        "Type": { "Id": 3, "Code": "Course Offering", "Name": "Course Offering" },
        "Name": "Computer Science Fundamentals",
        "Code": "COMPSCI 1026A",
        "HomeUrl": "/d2l/home/12345"
      },
      "Access": { "IsActive": true, "CanAccess": true }
    }
  ]
}
"""#

private let calendarEventJSON = #"""
{
  "CalendarEventId": 777,
  "OrgUnitId": 12345,
  "Title": "Midterm",
  "StartDateTime": "2026-10-12T03:00:00.000Z",
  "StartDay": null,
  "OrgUnitName": "Computer Science Fundamentals",
  "OrgUnitCode": "COMPSCI 1026A",
  "AssociatedEntity": null,
  "CalendarEventViewUrl": "/d2l/le/calendar/777",
  "EventType": 6
}
"""#

private let dropboxCalendarEventJSON = #"""
{
  "CalendarEventId": 778,
  "OrgUnitId": 12345,
  "Title": "Essay",
  "StartDateTime": "2026-11-01T03:00:00.000Z",
  "StartDay": null,
  "OrgUnitName": "Computer Science Fundamentals",
  "OrgUnitCode": "COMPSCI 1026A",
  "AssociatedEntity": {
    "AssociatedEntityType": "D2L.LE.Dropbox.Dropbox",
    "AssociatedEntityId": 55,
    "Link": "/d2l/lms/dropbox/user/folder_submit_files.d2l?db=55"
  },
  "CalendarEventViewUrl": "/d2l/le/calendar/778",
  "EventType": 6
}
"""#

private let dropboxFolderJSON = #"""
{ "Id": 55, "Name": "Essay", "DueDate": "2026-11-01T03:00:00.000Z", "IsHidden": false }
"""#

private let submissionJSON = #"""
{ "Status": "1", "Submissions": [{ "Id": 900, "SubmissionDate": "2026-10-30T12:00:00.000Z" }] }
"""#
