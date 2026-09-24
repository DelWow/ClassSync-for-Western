import SwiftUI

struct AssignmentRow: View {
    let assignment: MockAssignment

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.courseCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(assignment.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Text(assignment.dueDate, format: .dateTime.hour().minute())
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(assignment.courseCode), \(assignment.title), due \(assignment.dueDate.formatted(date: .abbreviated, time: .shortened))"
        )
    }
}

