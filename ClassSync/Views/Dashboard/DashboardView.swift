import SwiftUI

struct DashboardView: View {
    let assignments: [MockAssignment]

    var body: some View {
        NavigationStack {
            List(assignments) { assignment in
                VStack(alignment: .leading, spacing: 5) {
                    Text(assignment.courseCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(assignment.title)
                        .font(.headline)
                    Text(assignment.dueDate, format: .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Upcoming Assignments")
        }
    }
}

