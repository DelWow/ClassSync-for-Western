import Foundation

protocol BrightspaceHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

struct URLSessionBrightspaceHTTPClient: BrightspaceHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSession.shared.data(for: request)
    }
}

protocol BrightspaceClientProtocol: Sendable {
    func fetchActiveEnrollments() async throws -> [BrightspaceEnrollment]
    func fetchDueDateEvents(courseID: Int, start: Date, end: Date) async throws -> [BrightspaceCalendarEvent]
    func fetchDropboxFolders(courseID: Int) async throws -> [BrightspaceDropboxFolder]
    func fetchMySubmissions(courseID: Int, folderID: Int) async throws -> [BrightspaceEntityDropbox]
}

struct BrightspaceRetryPolicy: Sendable {
    static let standard = BrightspaceRetryPolicy(maxAttempts: 3)
    static let disabled = BrightspaceRetryPolicy(maxAttempts: 1)

    let maxAttempts: Int

    func delay(statusCode: Int, attempt: Int, retryAfter: String?) -> Duration? {
        guard attempt < maxAttempts, statusCode == 429 || (500..<600).contains(statusCode) else {
            return nil
        }
        if let retryAfter, let seconds = Double(retryAfter), seconds >= 0 {
            return .milliseconds(Int64(min(seconds, 30) * 1_000))
        }
        let milliseconds = min(250 * (1 << max(0, attempt - 1)), 2_000)
        return .milliseconds(Int64(milliseconds))
    }
}

struct BrightspaceClient: BrightspaceClientProtocol, Sendable {
    private let configuration: BrightspaceConfiguration
    private let tokenProvider: any BrightspaceAccessTokenProviding
    private let httpClient: any BrightspaceHTTPClient
    private let decoder: JSONDecoder
    private let retryPolicy: BrightspaceRetryPolicy
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        configuration: BrightspaceConfiguration = .western,
        tokenProvider: any BrightspaceAccessTokenProviding,
        httpClient: any BrightspaceHTTPClient = URLSessionBrightspaceHTTPClient(),
        retryPolicy: BrightspaceRetryPolicy = .standard,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.configuration = configuration
        self.tokenProvider = tokenProvider
        self.httpClient = httpClient
        self.retryPolicy = retryPolicy
        self.sleep = sleep
        decoder = JSONDecoder()
    }

    func fetchActiveEnrollments() async throws -> [BrightspaceEnrollment] {
        var enrollments: [BrightspaceEnrollment] = []
        var bookmark: String?
        var pageCount = 0

        repeat {
            var query = [
                URLQueryItem(name: "isActive", value: "true"),
                URLQueryItem(name: "canAccess", value: "true")
            ]
            if let bookmark {
                query.append(URLQueryItem(name: "bookmark", value: bookmark))
            }
            let page: BrightspacePagedResponse<BrightspaceEnrollment> = try await get(
                path: "/d2l/api/lp/\(configuration.lpVersion)/enrollments/myenrollments/",
                queryItems: query
            )
            enrollments.append(contentsOf: page.items)
            bookmark = page.pagingInfo.hasMoreItems ? page.pagingInfo.bookmark : nil
            pageCount += 1
        } while bookmark != nil && pageCount < 100

        return enrollments
    }

    func fetchDueDateEvents(courseID: Int, start: Date, end: Date) async throws -> [BrightspaceCalendarEvent] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let page: BrightspaceObjectListPage<BrightspaceCalendarEvent> = try await get(
            path: "/d2l/api/le/\(configuration.leVersion)/\(courseID)/calendar/events/myEvents/",
            queryItems: [
                URLQueryItem(name: "association", value: "1"),
                URLQueryItem(name: "eventType", value: "6"),
                URLQueryItem(name: "startDateTime", value: formatter.string(from: start)),
                URLQueryItem(name: "endDateTime", value: formatter.string(from: end))
            ]
        )
        return page.objects
    }

    func fetchDropboxFolders(courseID: Int) async throws -> [BrightspaceDropboxFolder] {
        try await get(path: "/d2l/api/le/\(configuration.leVersion)/\(courseID)/dropbox/folders/")
    }

    func fetchMySubmissions(courseID: Int, folderID: Int) async throws -> [BrightspaceEntityDropbox] {
        try await get(
            path: "/d2l/api/le/\(configuration.leVersion)/\(courseID)/dropbox/folders/\(folderID)/submissions/mysubmissions/"
        )
    }

    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Response {
        guard var components = URLComponents(
            url: configuration.tenantURL.appending(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw ProviderError.invalidResponse
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else { throw ProviderError.invalidResponse }

        let token = try await tokenProvider.accessToken()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        var attempt = 1
        while true {
          do {
            let (data, response) = try await httpClient.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw ProviderError.invalidResponse
            }
            switch response.statusCode {
            case 200..<300:
                do {
                    return try decoder.decode(Response.self, from: data)
                } catch {
                    AppLogger.brightspace.error("Brightspace response decoding failed")
                    throw ProviderError.invalidResponse
                }
            case 401:
                throw ProviderError.authenticationExpired
            case 403:
                throw ProviderError.forbidden
            case 429:
                if let delay = retryPolicy.delay(
                    statusCode: response.statusCode,
                    attempt: attempt,
                    retryAfter: response.value(forHTTPHeaderField: "Retry-After")
                ) {
                    attempt += 1
                    try await sleep(delay)
                    continue
                }
                throw ProviderError.rateLimited
            case 500..<600:
                if let delay = retryPolicy.delay(
                    statusCode: response.statusCode,
                    attempt: attempt,
                    retryAfter: response.value(forHTTPHeaderField: "Retry-After")
                ) {
                    attempt += 1
                    try await sleep(delay)
                    continue
                }
                throw ProviderError.unavailable
            default:
                throw ProviderError.invalidResponse
            }
          } catch let error as ProviderError {
            throw error
          } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost:
                throw ProviderError.networkUnavailable
            default:
                throw ProviderError.unavailable
            }
          }
        }
    }
}
