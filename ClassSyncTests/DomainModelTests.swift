import XCTest
@testable import ClassSync

final class DomainModelTests: XCTestCase {
    func testStableIdentifiersIncludeProvider() {
        XCTAssertEqual(
            Assignment.stableID(source: .brightspace, externalID: "123"),
            "brightspace:123"
        )
        XCTAssertNotEqual(
            Assignment.stableID(source: .brightspace, externalID: "123"),
            Assignment.stableID(source: .gradescope, externalID: "123")
        )
    }

    func testAssignmentsSortByDateWithMissingDatesLast() {
        let later = makeAssignment(id: "later", dueDate: Date(timeIntervalSince1970: 200))
        let missing = makeAssignment(id: "missing", dueDate: nil)
        let earlier = makeAssignment(id: "earlier", dueDate: Date(timeIntervalSince1970: 100))

        let sorted = [later, missing, earlier].sorted(by: Assignment.dueDateAscending)

        XCTAssertEqual(sorted.map(\.id), ["earlier", "later", "missing"])
    }
}

func makeAssignment(
    id: String = "assignment-1",
    title: String = "Assignment",
    dueDate: Date? = Date(timeIntervalSince1970: 1_000),
    status: AssignmentStatus = .upcoming,
    updatedAt: Date = Date(timeIntervalSince1970: 500)
) -> Assignment {
    Assignment(
        id: id,
        externalID: id,
        courseID: "course-1",
        courseName: "Course One",
        courseCode: "COURSE 1",
        title: title,
        dueDate: dueDate,
        source: .brightspace,
        url: URL(string: "https://example.com/assignments/\(id)"),
        status: status,
        createdAt: Date(timeIntervalSince1970: 100),
        updatedAt: updatedAt
    )
}

