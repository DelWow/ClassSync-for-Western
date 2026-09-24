import XCTest
@testable import ClassSync

final class ChangeDetectorTests: XCTestCase {
    private let detector = ChangeDetector()

    func testDueDateChangeIsDetected() {
        let old = makeAssignment(dueDate: Date(timeIntervalSince1970: 1_000))
        let new = makeAssignment(dueDate: Date(timeIntervalSince1970: 2_000))

        let changes = detector.detect(previous: [old], current: [new])

        XCTAssertEqual(changes.map(\.changeType), [.dueDate])
        XCTAssertNotNil(changes.first?.oldValue)
        XCTAssertNotNil(changes.first?.newValue)
    }

    func testEqualDatesDoNotProduceFalseChange() {
        let date = Date(timeIntervalSince1970: 1_000.1)
        let sameSecond = Date(timeIntervalSince1970: 1_000.9)

        let changes = detector.detect(
            previous: [makeAssignment(dueDate: date)],
            current: [makeAssignment(dueDate: sameSecond)]
        )

        XCTAssertTrue(changes.isEmpty)
    }

    func testTitleAndSubmissionStatusChangesAreDetected() {
        let old = makeAssignment(title: "Old Title", status: .upcoming)
        let new = makeAssignment(title: "New Title", status: .submitted)

        let changes = detector.detect(previous: [old], current: [new])

        XCTAssertEqual(Set(changes.map(\.changeType)), Set([.title, .submissionStatus]))
    }

    func testCreatedAndRemovedAssignmentsAreDetected() {
        let removed = makeAssignment(id: "removed")
        let created = makeAssignment(id: "created")

        let changes = detector.detect(previous: [removed], current: [created])

        XCTAssertEqual(Set(changes.map(\.changeType)), Set([.created, .removed]))
    }

    func testIdenticalSnapshotsProduceNoChanges() {
        let assignment = makeAssignment()

        XCTAssertTrue(detector.detect(previous: [assignment], current: [assignment]).isEmpty)
    }
}

