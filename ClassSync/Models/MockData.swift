import Foundation

enum MockData {
    static let courses: [Course] = [
        course(externalID: "cs3307", code: "CS 3307", name: "Object-Oriented Design", colorHex: "7C3AED"),
        course(externalID: "cs3342", code: "CS 3342", name: "Organization of Programming Languages", colorHex: "2563EB"),
        course(externalID: "stat2857", code: "STAT 2857", name: "Probability and Statistics", colorHex: "059669")
    ]

    static var assignments: [Assignment] {
        let now = Date()
        return [
            assignment(
                externalID: "cs3307-assignment-2",
                course: courses[0],
                title: "Assignment 2",
                dueDate: date(daysFromToday: 0, hour: 23, minute: 59),
                status: .upcoming,
                now: now
            ),
            assignment(
                externalID: "cs3342-quiz-4",
                course: courses[1],
                title: "Quiz 4",
                dueDate: date(daysFromToday: 1, hour: 10, minute: 0),
                status: .submitted,
                now: now
            ),
            assignment(
                externalID: "stat2857-lab-5",
                course: courses[2],
                title: "Lab 5",
                dueDate: date(daysFromToday: 3, hour: 17, minute: 0),
                status: .upcoming,
                now: now
            ),
            assignment(
                externalID: "cs3307-reading-quiz",
                course: courses[0],
                title: "Reading Quiz 3",
                dueDate: date(daysFromToday: -1, hour: 20, minute: 0),
                status: .overdue,
                now: now
            ),
            assignment(
                externalID: "cs3342-language-comparison-report",
                course: courses[1],
                title: "Programming Language Paradigms Comparative Analysis and Reflection",
                dueDate: date(daysFromToday: 5, hour: 23, minute: 59),
                status: .upcoming,
                now: now
            ),
            assignment(
                externalID: "stat2857-practice-set",
                course: courses[2],
                title: "Optional Practice Problem Set",
                dueDate: nil,
                status: .unknown,
                now: now
            )
        ]
        .sorted(by: Assignment.dueDateAscending)
    }

    private static func course(
        externalID: String,
        code: String,
        name: String,
        colorHex: String
    ) -> Course {
        Course(
            id: Course.stableID(source: .brightspace, externalID: externalID),
            externalID: externalID,
            code: code,
            name: name,
            source: .brightspace,
            isActive: true,
            colorHex: colorHex
        )
    }

    private static func assignment(
        externalID: String,
        course: Course,
        title: String,
        dueDate: Date?,
        status: AssignmentStatus,
        now: Date
    ) -> Assignment {
        Assignment(
            id: Assignment.stableID(source: .brightspace, externalID: externalID),
            externalID: externalID,
            courseID: course.id,
            courseName: course.name,
            courseCode: course.code,
            title: title,
            dueDate: dueDate,
            source: .brightspace,
            url: URL(string: "https://westernu.brightspace.com/d2l/home/\(externalID)"),
            status: status,
            createdAt: now.addingTimeInterval(-86_400),
            updatedAt: now
        )
    }

    private static func date(daysFromToday: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let targetDay = calendar.date(
            byAdding: .day,
            value: daysFromToday,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetDay
        ) ?? targetDay
    }
}

