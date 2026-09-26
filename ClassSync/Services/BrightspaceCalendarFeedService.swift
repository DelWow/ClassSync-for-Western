import CryptoKit
import Foundation

enum BrightspaceCalendarFeedError: LocalizedError, Equatable {
    case invalidURL
    case unexpectedHost
    case notConfigured
    case accessDenied
    case responseTooLarge
    case invalidCalendar

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter the private HTTPS calendar-feed URL copied from Brightspace."
        case .unexpectedHost:
            "The calendar feed must come from westernu.brightspace.com."
        case .notConfigured:
            "Connect a Brightspace calendar feed before syncing it."
        case .accessDenied:
            "Brightspace rejected the calendar feed. Copy a new private feed URL and reconnect it."
        case .responseTooLarge:
            "The calendar feed was unexpectedly large and was not imported."
        case .invalidCalendar:
            "Brightspace returned a calendar format that ClassSync could not read."
        }
    }
}

struct BrightspaceCalendarFeedConfiguration {
    static let keychainAccount = "brightspace-private-calendar-feed"
    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    func save(urlString: String) throws {
        let url = try validatedURL(urlString)
        try keychain.saveToken(Data(url.absoluteString.utf8), account: Self.keychainAccount)
    }

    func readURL() throws -> URL? {
        guard let data = try keychain.readToken(account: Self.keychainAccount),
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return try validatedURL(string)
    }

    func disconnect() throws {
        try keychain.deleteToken(account: Self.keychainAccount)
    }

    func isConnected() -> Bool {
        (try? readURL()) != nil
    }

    func validatedURL(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.user == nil,
              components.password == nil,
              let host = components.host?.lowercased(),
              let url = components.url,
              !components.path.isEmpty
        else { throw BrightspaceCalendarFeedError.invalidURL }
        guard host == "westernu.brightspace.com" else {
            throw BrightspaceCalendarFeedError.unexpectedHost
        }
        guard components.path.lowercased().contains("/d2l/le/calendar/") else {
            throw BrightspaceCalendarFeedError.invalidURL
        }
        return url
    }
}

struct CalendarFeedSnapshot: Equatable, Sendable {
    let courses: [Course]
    let assignments: [Assignment]

    static let empty = CalendarFeedSnapshot(courses: [], assignments: [])
}

struct ICalendarParser: Sendable {
    func parse(_ data: Data, importedAt: Date = Date(), defaultTimeZone: TimeZone = .current) throws -> CalendarFeedSnapshot {
        guard let raw = String(data: data, encoding: .utf8), raw.contains("BEGIN:VCALENDAR") else {
            throw BrightspaceCalendarFeedError.invalidCalendar
        }

        let lines = unfold(raw)
        var eventFields: [CalendarField] = []
        var isInsideEvent = false
        var events: [ParsedEvent] = []

        for line in lines {
            if line == "BEGIN:VEVENT" || line == "BEGIN:VTODO" {
                isInsideEvent = true
                eventFields.removeAll(keepingCapacity: true)
                continue
            }
            if line == "END:VEVENT" || line == "END:VTODO" {
                if let event = makeEvent(from: eventFields, defaultTimeZone: defaultTimeZone) {
                    events.append(event)
                }
                isInsideEvent = false
                continue
            }
            guard isInsideEvent, let field = parseField(line) else { continue }
            eventFields.append(field)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = defaultTimeZone
        let earliestRelevantDate = calendar.date(byAdding: .day, value: -60, to: importedAt) ?? .distantPast
        let latestRelevantDate = calendar.date(byAdding: .day, value: 400, to: importedAt) ?? .distantFuture
        let relevantEvents = events.filter {
            $0.dueDate >= earliestRelevantDate && $0.dueDate <= latestRelevantDate
        }

        var courseByID: [String: Course] = [:]
        var assignmentsByID: [String: Assignment] = [:]
        for event in relevantEvents {
            let metadata = inferCourse(for: event)
            let courseExternalID = digest(metadata.code.lowercased())
            let courseID = Course.stableID(source: .brightspaceCalendar, externalID: courseExternalID)
            courseByID[courseID] = Course(
                id: courseID,
                externalID: courseExternalID,
                code: metadata.code,
                name: metadata.name,
                source: .brightspaceCalendar,
                isActive: true,
                colorHex: nil
            )

            let externalID = event.uid.isEmpty
                ? digest("\(event.summary)|\(event.dueDate.timeIntervalSince1970)")
                : digest(event.uid)
            let id = Assignment.stableID(source: .brightspaceCalendar, externalID: externalID)
            assignmentsByID[id] = Assignment(
                id: id,
                externalID: externalID,
                courseID: courseID,
                courseName: metadata.name,
                courseCode: metadata.code,
                title: cleanedTitle(event.summary, courseCode: metadata.code),
                dueDate: event.dueDate,
                source: .brightspaceCalendar,
                url: validatedEventURL(event.url),
                status: event.dueDate < importedAt ? .overdue : .upcoming,
                createdAt: importedAt,
                updatedAt: event.lastModified ?? importedAt
            )
        }

        return CalendarFeedSnapshot(
            courses: courseByID.values.sorted { $0.code.localizedStandardCompare($1.code) == .orderedAscending },
            assignments: assignmentsByID.values.sorted(by: Assignment.dueDateAscending)
        )
    }

    private func unfold(_ raw: String) -> [String] {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        for line in normalized.components(separatedBy: "\n") {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !lines.isEmpty {
                lines[lines.count - 1] += String(line.dropFirst())
            } else {
                lines.append(line)
            }
        }
        return lines
    }

    private func parseField(_ line: String) -> CalendarField? {
        guard let separator = line.firstIndex(of: ":") else { return nil }
        let descriptor = String(line[..<separator])
        let value = String(line[line.index(after: separator)...])
        let pieces = descriptor.split(separator: ";", omittingEmptySubsequences: false)
        guard let rawName = pieces.first else { return nil }
        var parameters: [String: String] = [:]
        for rawParameter in pieces.dropFirst() {
            let pair = rawParameter.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { parameters[pair[0].uppercased()] = pair[1] }
        }
        return CalendarField(name: rawName.uppercased(), parameters: parameters, value: unescape(value))
    }

    private func makeEvent(from fields: [CalendarField], defaultTimeZone: TimeZone) -> ParsedEvent? {
        func field(_ names: String...) -> CalendarField? {
            names.compactMap { name in fields.first { $0.name == name } }.first
        }
        guard let summary = field("SUMMARY")?.value.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty,
              let dueField = field("DUE", "DTSTART", "DTEND"),
              let dueDate = parseDate(dueField, defaultTimeZone: defaultTimeZone)
        else { return nil }

        return ParsedEvent(
            uid: field("UID")?.value ?? "",
            summary: summary,
            description: field("DESCRIPTION", "X-ALT-DESC")?.value ?? "",
            categories: fields.filter { $0.name == "CATEGORIES" }.flatMap { $0.value.split(separator: ",").map(String.init) },
            dueDate: dueDate,
            lastModified: field("LAST-MODIFIED", "DTSTAMP") .flatMap { parseDate($0, defaultTimeZone: defaultTimeZone) },
            url: field("URL")?.value
        )
    }

    private func parseDate(_ field: CalendarField, defaultTimeZone: TimeZone) -> Date? {
        let value = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDateOnly = field.parameters["VALUE"]?.uppercased() == "DATE" || value.count == 8
        let timeZone = field.parameters["TZID"].flatMap(TimeZone.init(identifier:)) ?? defaultTimeZone

        if isDateOnly {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = timeZone
            formatter.dateFormat = "yyyyMMdd"
            guard let day = formatter.date(from: value) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(bySettingHour: 23, minute: 59, second: 0, of: day)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = value.hasSuffix("Z") ? TimeZone(secondsFromGMT: 0) : timeZone
        formatter.dateFormat = value.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        if let date = formatter.date(from: value) { return date }
        formatter.dateFormat = value.hasSuffix("Z") ? "yyyyMMdd'T'HHmm'Z'" : "yyyyMMdd'T'HHmm"
        return formatter.date(from: value)
    }

    private func inferCourse(for event: ParsedEvent) -> (code: String, name: String) {
        let candidates = event.categories + [event.summary, event.description]
        let combined = candidates.joined(separator: " \n ")
        let pattern = #"(?i)\b([A-Z]{2,8})\s*[- ]?\s*(\d{3,4}[A-Z]?)\b"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: combined, range: NSRange(combined.startIndex..., in: combined)),
           let subjectRange = Range(match.range(at: 1), in: combined),
           let numberRange = Range(match.range(at: 2), in: combined) {
            let code = "\(combined[subjectRange].uppercased()) \(combined[numberRange].uppercased())"
            let categoryName = event.categories.first { category in
                let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count > code.count && !trimmed.lowercased().contains("calendar")
            }
            return (code, categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? code)
        }
        let category = event.categories.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (category.flatMap { $0.isEmpty ? nil : $0 } ?? "BRIGHTSPACE", category.flatMap { $0.isEmpty ? nil : $0 } ?? "Brightspace Calendar")
    }

    private func cleanedTitle(_ title: String, courseCode: String) -> String {
        let withoutCode = title.replacingOccurrences(of: courseCode, with: "", options: [.caseInsensitive])
        let cleaned = withoutCode.trimmingCharacters(in: CharacterSet(charactersIn: "-–—:| []()"))
        return cleaned.isEmpty ? title : cleaned
    }

    private func validatedEventURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value) else { return nil }
        return AssignmentURLValidator.validatedURL(url, source: .brightspaceCalendar)
    }

    private func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private struct CalendarField: Sendable {
    let name: String
    let parameters: [String: String]
    let value: String
}

private struct ParsedEvent: Sendable {
    let uid: String
    let summary: String
    let description: String
    let categories: [String]
    let dueDate: Date
    let lastModified: Date?
    let url: String?
}

actor BrightspaceCalendarFeedClient {
    private let configuration: BrightspaceCalendarFeedConfiguration
    private let session: URLSession
    private let parser: ICalendarParser
    private var cachedSnapshot: (snapshot: CalendarFeedSnapshot, loadedAt: Date)?
    private var inFlight: Task<CalendarFeedSnapshot, Error>?

    init(
        configuration: BrightspaceCalendarFeedConfiguration = BrightspaceCalendarFeedConfiguration(),
        session: URLSession = URLSession(configuration: .ephemeral),
        parser: ICalendarParser = ICalendarParser()
    ) {
        self.configuration = configuration
        self.session = session
        self.parser = parser
    }

    func snapshot() async throws -> CalendarFeedSnapshot {
        if let cachedSnapshot, Date().timeIntervalSince(cachedSnapshot.loadedAt) < 10 {
            return cachedSnapshot.snapshot
        }
        if let inFlight { return try await inFlight.value }
        guard let url = try configuration.readURL() else { return .empty }

        let session = self.session
        let parser = self.parser
        let task = Task<CalendarFeedSnapshot, Error> {
            do {
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
                if response.statusCode == 401 || response.statusCode == 403 {
                    throw BrightspaceCalendarFeedError.accessDenied
                }
                guard (200..<300).contains(response.statusCode) else { throw ProviderError.unavailable }
                guard data.count <= 5_000_000 else { throw BrightspaceCalendarFeedError.responseTooLarge }
                return try parser.parse(data)
            } catch let error as URLError {
                AppLogger.brightspace.error("Calendar feed request failed with URL error code: \(error.code.rawValue, privacy: .public)")
                throw ProviderError.networkUnavailable
            }
        }
        inFlight = task
        do {
            let snapshot = try await task.value
            inFlight = nil
            cachedSnapshot = (snapshot, Date())
            return snapshot
        } catch {
            inFlight = nil
            throw error
        }
    }

    func invalidateCache() {
        inFlight?.cancel()
        inFlight = nil
        cachedSnapshot = nil
    }
}

struct BrightspaceCalendarFeedProvider: AssignmentProvider {
    let id = "brightspace-calendar-feed"
    let name = "Brightspace Calendar"
    let capabilities: ProviderCapabilities = [.courses, .assignments]
    let managedSources: Set<AssignmentSource> = [.brightspaceCalendar]
    private let client: BrightspaceCalendarFeedClient

    init(client: BrightspaceCalendarFeedClient = BrightspaceCalendarFeedClient()) {
        self.client = client
    }

    func authenticate() async throws {}
    func fetchCourses() async throws -> [Course] { try await client.snapshot().courses }
    func fetchAssignments() async throws -> [Assignment] { try await client.snapshot().assignments }
}
