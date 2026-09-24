import EventKit
import Foundation
import Combine

enum CalendarPermissionState: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

struct CalendarDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let sourceTitle: String
}

struct CalendarEventDraft: Equatable, Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String
    let url: URL?
}

@MainActor
protocol CalendarEventClient: AnyObject {
    func authorizationStatus() -> CalendarPermissionState
    func requestFullAccess() async throws -> Bool
    func writableCalendars() -> [CalendarDescriptor]
    func defaultCalendarID() -> String?
    func createCalendar(title: String) throws -> CalendarDescriptor
    func upsert(eventID: String?, draft: CalendarEventDraft, calendarID: String) throws -> String
    func remove(eventID: String) throws
}

@MainActor
final class EventKitCalendarClient: CalendarEventClient {
    private let store = EKEventStore()

    func authorizationStatus() -> CalendarPermissionState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            .notDetermined
        case .fullAccess:
            .authorized
        case .denied, .restricted, .writeOnly:
            .denied
        @unknown default:
            .denied
        }
    }

    func requestFullAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func writableCalendars() -> [CalendarDescriptor] {
        store.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map { CalendarDescriptor(id: $0.calendarIdentifier, title: $0.title, sourceTitle: $0.source.title) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func defaultCalendarID() -> String? {
        store.defaultCalendarForNewEvents?.calendarIdentifier
    }

    func createCalendar(title: String) throws -> CalendarDescriptor {
        guard let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .local }) else {
            throw AppError.calendarPermissionDenied
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = title
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return CalendarDescriptor(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: source.title
        )
    }

    func upsert(eventID: String?, draft: CalendarEventDraft, calendarID: String) throws -> String {
        guard let calendar = store.calendar(withIdentifier: calendarID), calendar.allowsContentModifications else {
            throw AppError.calendarPermissionDenied
        }
        let event = eventID.flatMap(store.event(withIdentifier:)) ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.notes = draft.notes
        event.url = draft.url
        try store.save(event, span: .thisEvent, commit: true)
        guard let identifier = event.eventIdentifier else { throw AppError.persistenceUnavailable }
        return identifier
    }

    func remove(eventID: String) throws {
        guard let event = store.event(withIdentifier: eventID) else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }
}

protocol CalendarEventLinkStoring: AnyObject {
    var links: [String: String] { get set }
}

final class UserDefaultsCalendarEventLinkStore: CalendarEventLinkStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "calendarEventLinks") {
        self.defaults = defaults
        self.key = key
    }

    var links: [String: String] {
        get { defaults.dictionary(forKey: key) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: key) }
    }
}

@MainActor
final class CalendarIntegrationService: ObservableObject {
    @Published private(set) var permission: CalendarPermissionState = .notDetermined
    @Published private(set) var calendars: [CalendarDescriptor] = []
    @Published private(set) var errorMessage: String?

    private let client: any CalendarEventClient
    private let linkStore: any CalendarEventLinkStoring

    convenience init() {
        self.init(
            client: EventKitCalendarClient(),
            linkStore: UserDefaultsCalendarEventLinkStore()
        )
    }

    init(
        client: any CalendarEventClient,
        linkStore: any CalendarEventLinkStoring
    ) {
        self.client = client
        self.linkStore = linkStore
    }

    func refresh() {
        permission = client.authorizationStatus()
        calendars = permission == .authorized ? client.writableCalendars() : []
    }

    func requestAccess() async {
        do {
            permission = try await client.requestFullAccess() ? .authorized : .denied
            calendars = permission == .authorized ? client.writableCalendars() : []
            errorMessage = permission == .denied ? AppError.calendarPermissionDenied.localizedDescription : nil
        } catch {
            permission = .denied
            errorMessage = AppError.calendarPermissionDenied.localizedDescription
        }
    }

    func createClassSyncCalendar() -> String? {
        guard permission == .authorized else { return nil }
        do {
            let created = try client.createCalendar(title: "ClassSync")
            calendars = client.writableCalendars()
            errorMessage = nil
            return created.id
        } catch {
            errorMessage = "ClassSync could not create a calendar. Choose an existing writable calendar instead."
            return nil
        }
    }

    func synchronize(
        assignments: [Assignment],
        calendarID: String?,
        removeMissingEvents: Bool = true
    ) {
        refresh()
        guard permission == .authorized else {
            errorMessage = AppError.calendarPermissionDenied.localizedDescription
            return
        }
        guard let targetID = calendarID ?? client.defaultCalendarID() else {
            errorMessage = "Choose a writable calendar before enabling calendar sync."
            return
        }

        do {
            var links = linkStore.links
            let eligible = assignments.filter { $0.dueDate != nil }
            let currentIDs = Set(eligible.map(\.id))

            for assignment in eligible {
                guard let dueDate = assignment.dueDate else { continue }
                let draft = CalendarEventDraft(
                    title: "\(assignment.courseCode) — \(assignment.title)",
                    startDate: dueDate,
                    endDate: dueDate.addingTimeInterval(60 * 60),
                    notes: "Synced by ClassSync from \(assignment.source.displayName).",
                    url: AssignmentURLValidator.validatedURL(for: assignment)
                )
                links[assignment.id] = try client.upsert(
                    eventID: links[assignment.id],
                    draft: draft,
                    calendarID: targetID
                )
            }

            if removeMissingEvents {
                for assignmentID in Set(links.keys).subtracting(currentIDs) {
                    if let eventID = links.removeValue(forKey: assignmentID) {
                        try client.remove(eventID: eventID)
                    }
                }
            }
            linkStore.links = links
            errorMessage = nil
        } catch {
            AppLogger.database.error("Apple Calendar synchronization failed")
            errorMessage = "Apple Calendar could not be updated. Check the selected calendar and try again."
        }
    }

    func disableAndRemoveEvents() {
        var links = linkStore.links
        do {
            for eventID in links.values { try client.remove(eventID: eventID) }
            links.removeAll()
            linkStore.links = links
            errorMessage = nil
        } catch {
            errorMessage = "Some ClassSync calendar events could not be removed."
        }
    }
}
