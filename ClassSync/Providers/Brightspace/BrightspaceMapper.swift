import Foundation

struct BrightspaceMapper: Sendable {
    private let tenantURL: URL
    private let now: @Sendable () -> Date

    init(
        tenantURL: URL = BrightspaceConfiguration.western.tenantURL,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tenantURL = tenantURL
        self.now = now
    }

    func course(from enrollment: BrightspaceEnrollment) -> Course? {
        guard enrollment.isCourseOffering else { return nil }
        let externalID = String(enrollment.orgUnit.id)
        return Course(
            id: Course.stableID(source: .brightspace, externalID: externalID),
            externalID: externalID,
            code: enrollment.orgUnit.code ?? "COURSE",
            name: enrollment.orgUnit.name,
            source: .brightspace,
            isActive: enrollment.access.isActive && enrollment.access.canAccess,
            colorHex: nil
        )
    }

    func assignment(from event: BrightspaceCalendarEvent, course: Course) -> Assignment? {
        guard event.eventType == nil || event.eventType == 6 else { return nil }
        let externalID = "calendar:\(event.id)"
        let dueDate = parseDate(event.startDateTime ?? event.startDay)
        return Assignment(
            id: Assignment.stableID(source: .brightspace, externalID: externalID),
            externalID: externalID,
            courseID: course.id,
            courseName: course.name,
            courseCode: course.code,
            title: event.title,
            dueDate: dueDate,
            source: .brightspace,
            url: resolveURL(event.viewURL ?? event.associatedEntity?.link),
            status: status(dueDate: dueDate, submitted: false),
            createdAt: now(),
            updatedAt: now()
        )
    }

    func assignment(
        from folder: BrightspaceDropboxFolder,
        course: Course,
        submitted: Bool
    ) -> Assignment? {
        guard !folder.isHidden else { return nil }
        let externalID = "dropbox:\(folder.id)"
        let dueDate = parseDate(folder.dueDate)
        return Assignment(
            id: Assignment.stableID(source: .brightspace, externalID: externalID),
            externalID: externalID,
            courseID: course.id,
            courseName: course.name,
            courseCode: course.code,
            title: folder.name,
            dueDate: dueDate,
            source: .brightspace,
            url: tenantURL.appending(path: "/d2l/lms/dropbox/user/folders_list.d2l", directoryHint: .notDirectory),
            status: status(dueDate: dueDate, submitted: submitted),
            createdAt: now(),
            updatedAt: now()
        )
    }

    func dropboxFolderID(from event: BrightspaceCalendarEvent) -> Int? {
        guard event.associatedEntity?.type == "D2L.LE.Dropbox.Dropbox" else { return nil }
        return event.associatedEntity?.id
    }

    private func status(dueDate: Date?, submitted: Bool) -> AssignmentStatus {
        if submitted { return .submitted }
        guard let dueDate else { return .unknown }
        return dueDate < now() ? .overdue : .upcoming
    }

    private func resolveURL(_ rawValue: String?) -> URL? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        if let absolute = URL(string: rawValue), absolute.scheme != nil { return absolute }
        return URL(string: rawValue, relativeTo: tenantURL)?.absoluteURL
    }

    private func parseDate(_ rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: rawValue) { return date }

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: rawValue) { return date }

        return try? Date(rawValue, strategy: .iso8601)
    }
}
