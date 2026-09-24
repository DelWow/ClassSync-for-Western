import Foundation

struct MockAssignment: Identifiable, Hashable {
    let id: String
    let courseCode: String
    let title: String
    let dueDate: Date

    static var upcoming: [MockAssignment] {
        [
            MockAssignment(
                id: "mock-cs3307-assignment-2",
                courseCode: "CS 3307",
                title: "Assignment 2",
                dueDate: date(daysFromToday: 0, hour: 23, minute: 59)
            ),
            MockAssignment(
                id: "mock-cs3342-quiz-4",
                courseCode: "CS 3342",
                title: "Quiz 4",
                dueDate: date(daysFromToday: 1, hour: 10, minute: 0)
            ),
            MockAssignment(
                id: "mock-stat2857-lab-5",
                courseCode: "STAT 2857",
                title: "Lab 5",
                dueDate: date(daysFromToday: 3, hour: 17, minute: 0)
            )
        ]
        .sorted { $0.dueDate < $1.dueDate }
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

