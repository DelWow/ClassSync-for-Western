import XCTest
@testable import ClassSync

final class ImportIntegrationTests: XCTestCase {
    func testSyllabusParserFindsCourseAndDatedAssessments() throws {
        let text = """
        COMPSCI 3307A — Software Engineering
        Assignment 1 due October 8, 2026 at 11:59 PM
        Midterm Exam — October 20, 2026 at 7:00 PM
        Weekly lecture on Thursdays
        """

        let result = try SyllabusImportService().parse(
            text: text,
            filename: "course-outline",
            now: makeTorontoDate(2026, 9, 1, 12, 0)
        )

        XCTAssertEqual(result.courseCode, "COMPSCI 3307A")
        XCTAssertEqual(result.courseName, "Software Engineering")
        XCTAssertEqual(result.drafts.map(\.title), ["Assignment 1", "Midterm Exam"])
    }

    func testSyllabusModelsAreStableAcrossRepeatedImports() throws {
        let service = SyllabusImportService()
        let result = try service.parse(
            text: "PSYCH 1000 — Introduction to Psychology\nQuiz 1 due November 2, 2026 at 9:00 AM",
            filename: "psych",
            now: makeTorontoDate(2026, 9, 1, 12, 0)
        )

        let first = service.makeModels(from: result, importedAt: Date(timeIntervalSince1970: 100))
        let second = service.makeModels(from: result, importedAt: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(first.0.id, second.0.id)
        XCTAssertEqual(first.1.map(\.id), second.1.map(\.id))
        XCTAssertEqual(first.1.first?.source, .syllabus)
    }

    func testSyllabusAssignmentIDRemainsStableWhenDueDateIsCorrected() throws {
        let service = SyllabusImportService()
        let now = makeTorontoDate(2026, 9, 1, 12, 0)
        let firstResult = try service.parse(
            text: "PSYCH 1000 — Psychology\nQuiz 1 due October 2, 2026",
            filename: "psych",
            now: now
        )
        let correctedResult = try service.parse(
            text: "PSYCH 1000 — Psychology\nQuiz 1 due October 9, 2026",
            filename: "psych",
            now: now
        )

        let first = service.makeModels(from: firstResult, importedAt: now)
        let corrected = service.makeModels(from: correctedResult, importedAt: now)

        XCTAssertEqual(first.1.first?.id, corrected.1.first?.id)
        XCTAssertNotEqual(first.1.first?.dueDate, corrected.1.first?.dueDate)
    }

    func testYearlessWinterSyllabusDatesResolveIntoNextCalendarYear() throws {
        let now = makeTorontoDate(2026, 9, 24, 12, 0)
        let service = SyllabusImportService()
        let result = try service.parse(
            text: "PSYCH 1000 — Psychology\nFinal Exam due April 10 at 7:00 PM",
            filename: "winter-course",
            now: now
        )
        let models = service.makeModels(from: result, importedAt: now)

        XCTAssertEqual(result.drafts.first?.dueDate, makeTorontoDate(2027, 4, 10, 19, 0))
        XCTAssertEqual(models.1.first?.status, .upcoming)
    }

    func testRecentYearlessFallDateRemainsInCurrentAcademicYear() throws {
        let result = try SyllabusImportService().parse(
            text: "COMPSCI 3307 — Software Engineering\nAssignment 1 due Sept. 10 at 23:59",
            filename: "fall-course",
            now: makeTorontoDate(2026, 9, 24, 12, 0)
        )

        XCTAssertEqual(result.drafts.first?.dueDate, makeTorontoDate(2026, 9, 10, 23, 59))
    }

    func testSyllabusParserAcceptsHourOnlyMeridiemTimes() throws {
        let result = try SyllabusImportService().parse(
            text: "WRITING 2101 — Writing\nEssay due 24 September 2026 at 11 PM",
            filename: "writing",
            now: makeTorontoDate(2026, 9, 1, 12, 0)
        )

        XCTAssertEqual(result.drafts.first?.dueDate, makeTorontoDate(2026, 9, 24, 23, 0))
    }

    func testSyllabusParserJoinsAssessmentAndDateSplitAcrossPDFLines() throws {
        let text = """
        COMPSCI 3307A — Software Engineering
        Assignment 1
        15%
        September 30, 2026
        24 October 2026
        Final Exam
        """

        let result = try SyllabusImportService().parse(
            text: text,
            filename: "table-layout",
            now: makeTorontoDate(2026, 9, 1, 12, 0)
        )

        XCTAssertEqual(Set(result.drafts.map(\.title)), ["Assignment 1", "Final Exam"])
        XCTAssertEqual(
            Set(result.drafts.map(\.dueDate)),
            [makeTorontoDate(2026, 9, 30, 23, 59), makeTorontoDate(2026, 10, 24, 23, 59)]
        )
    }

    func testSyllabusParserWarnsAboutClearlyStaleExplicitDates() throws {
        let result = try SyllabusImportService().parse(
            text: "HISTORY 2201 — History\nResearch Paper due March 1, 2024",
            filename: "old-outline",
            now: makeTorontoDate(2026, 9, 24, 12, 0)
        )

        XCTAssertTrue(result.warnings.contains { $0.contains("well in the past") })
    }

    func testICalendarParserHandlesFoldingTimeZonesAndAllDayValues() throws {
        let calendar = """
        BEGIN:VCALENDAR\r
        VERSION:2.0\r
        BEGIN:VEVENT\r
        UID:assignment-1@example\r
        DTSTART;TZID=America/Toronto:20261008T235900\r
        SUMMARY:COMPSCI 3307A - Assignment 1\r
        CATEGORIES:COMPSCI 3307A - Software\r
         Engineering\r
        URL:https://westernu.brightspace.com/d2l/le/calendar/123\r
        END:VEVENT\r
        BEGIN:VEVENT\r
        UID:exam-1@example\r
        DTSTART;VALUE=DATE:20261210\r
        SUMMARY:COMPSCI 3307A Final Exam\r
        CATEGORIES:COMPSCI 3307A\r
        END:VEVENT\r
        END:VCALENDAR\r
        """

        let result = try ICalendarParser().parse(
            Data(calendar.utf8),
            importedAt: makeTorontoDate(2026, 9, 1, 12, 0),
            defaultTimeZone: TimeZone(identifier: "America/Toronto")!
        )

        XCTAssertEqual(result.courses.count, 1)
        XCTAssertEqual(result.courses.first?.code, "COMPSCI 3307A")
        XCTAssertEqual(result.assignments.count, 2)
        XCTAssertEqual(result.assignments.first?.dueDate, makeTorontoDate(2026, 10, 8, 23, 59))
        XCTAssertEqual(result.assignments.last?.dueDate, makeTorontoDate(2026, 12, 10, 23, 59))
        XCTAssertEqual(result.assignments.first?.source, .brightspaceCalendar)
    }

    func testICalendarParserExcludesStaleAndUnreasonablyDistantEvents() throws {
        let calendar = """
        BEGIN:VCALENDAR
        VERSION:2.0
        BEGIN:VEVENT
        UID:old-event
        DTSTART:20240110T120000Z
        SUMMARY:COMPSCI 3307 Old Assignment
        CATEGORIES:COMPSCI 3307
        END:VEVENT
        BEGIN:VEVENT
        UID:current-event
        DTSTART:20261010T120000Z
        SUMMARY:COMPSCI 3307 Current Assignment
        CATEGORIES:COMPSCI 3307
        END:VEVENT
        BEGIN:VEVENT
        UID:distant-event
        DTSTART:20290110T120000Z
        SUMMARY:COMPSCI 3307 Distant Assignment
        CATEGORIES:COMPSCI 3307
        END:VEVENT
        END:VCALENDAR
        """

        let result = try ICalendarParser().parse(
            Data(calendar.utf8),
            importedAt: makeTorontoDate(2026, 9, 24, 12, 0),
            defaultTimeZone: TimeZone(identifier: "America/Toronto")!
        )

        XCTAssertEqual(result.assignments.map(\.title), ["Current Assignment"])
        XCTAssertEqual(result.courses.count, 1)
    }

    func testCalendarFeedURLValidationRejectsLookalikeAndCredentials() throws {
        let configuration = BrightspaceCalendarFeedConfiguration()
        XCTAssertNoThrow(try configuration.validatedURL("https://westernu.brightspace.com/d2l/le/calendar/feed/user/feed.ics?token=secret"))
        XCTAssertThrowsError(try configuration.validatedURL("https://westernu.brightspace.com.example.org/d2l/le/calendar/feed.ics"))
        XCTAssertThrowsError(try configuration.validatedURL("https://student@westernu.brightspace.com/d2l/le/calendar/feed.ics"))
        XCTAssertThrowsError(try configuration.validatedURL("http://westernu.brightspace.com/d2l/le/calendar/feed.ics"))
    }

    func testEmailDetectorCreatesReviewableDeadlineSuggestion() {
        let oldDate = makeTorontoDate(2026, 10, 8, 23, 59)
        let assignment = makeAssignment(title: "Assignment 1", dueDate: oldDate)
        let course = Course(
            id: assignment.courseID,
            externalID: "course-1",
            code: "COMPSCI 3307A",
            name: "Software Engineering",
            source: .syllabus,
            isActive: true,
            colorHex: nil
        )
        let message = SchoolEmailMessage(
            id: "message-1",
            subject: "COMPSCI 3307A Assignment 1 deadline extended",
            sender: "Professor <professor@uwo.ca>",
            body: "Assignment 1 is now due October 10, 2026 at 10:00 PM."
        )

        let suggestions = EmailDeadlineChangeDetector().detect(
            messages: [message],
            assignments: [assignment],
            courses: [course],
            now: makeTorontoDate(2026, 9, 24, 12, 0)
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.assignmentID, assignment.id)
        XCTAssertEqual(suggestions.first?.proposedDueDate, makeTorontoDate(2026, 10, 10, 22, 0))
        XCTAssertTrue(EmailDeadlineChangeDetector().detect(
            messages: [message],
            assignments: [assignment],
            courses: [course],
            processedMessageIDs: [message.id]
        ).isEmpty)
    }

    func testSourceReconcilerPrefersCalendarButKeepsSyllabusAsFallback() {
        let syllabus = Assignment(
            id: "syllabus:item",
            externalID: "syllabus-item",
            courseID: "syllabus:course",
            courseName: "Software Engineering",
            courseCode: "COMPSCI 3307A",
            title: "Assignment 1",
            dueDate: Date(timeIntervalSince1970: 1_000),
            source: .syllabus,
            url: nil,
            status: .upcoming,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let feed = Assignment(
            id: "brightspaceCalendar:item",
            externalID: "feed-item",
            courseID: "brightspaceCalendar:course",
            courseName: "Software Engineering",
            courseCode: "COMPSCI-3307A",
            title: "Assignment 1",
            dueDate: Date(timeIntervalSince1970: 2_000),
            source: .brightspaceCalendar,
            url: nil,
            status: .upcoming,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(SourceReconciler().assignments([syllabus, feed]), [feed])
        XCTAssertEqual(SourceReconciler().assignments([syllabus]), [syllabus])
    }

    @MainActor
    func testSyncPreservesSourcesNotManagedByProvider() async {
        let syllabus = Assignment(
            id: "syllabus:item",
            externalID: "item",
            courseID: "syllabus:course",
            courseName: "Course",
            courseCode: "COURSE 1000",
            title: "Syllabus Item",
            dueDate: Date(timeIntervalSince1970: 1_000),
            source: .syllabus,
            url: nil,
            status: .upcoming,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let feed = Assignment(
            id: "brightspaceCalendar:item",
            externalID: "item",
            courseID: "brightspaceCalendar:course",
            courseName: "Course",
            courseCode: "COURSE 1000",
            title: "Feed Item",
            dueDate: Date(timeIntervalSince1970: 2_000),
            source: .brightspaceCalendar,
            url: nil,
            status: .upcoming,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let store = InMemoryAssignmentStore(assignments: [syllabus])
        let result = await SyncService(provider: FeedFixtureProvider(assignments: [feed]), store: store).sync()

        XCTAssertEqual(Set(result?.assignments.map(\.id) ?? []), [syllabus.id, feed.id])
    }

    private func makeTorontoDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

private struct FeedFixtureProvider: AssignmentProvider {
    let id = "feed-fixture"
    let name = "Feed Fixture"
    let capabilities: ProviderCapabilities = [.courses, .assignments]
    let managedSources: Set<AssignmentSource> = [.brightspaceCalendar]
    let assignments: [Assignment]

    func authenticate() async throws {}
    func fetchCourses() async throws -> [Course] { [] }
    func fetchAssignments() async throws -> [Assignment] { assignments }
}
