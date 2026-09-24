import SwiftUI

struct AssignmentRow: View {
    let assignment: Assignment
    var courseColorHex: String? = nil

    var body: some View {
        if let url = AssignmentURLValidator.validatedURL(for: assignment) {
            Link(destination: url) {
                rowContent
            }
            .buttonStyle(.plain)
            .help("Open in \(assignment.source.displayName)")
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(Color(hex: courseColorHex) ?? .secondary)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(assignment.courseCode)
                    Text("•")
                    Text(assignment.source.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(assignment.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                if assignment.status == .submitted {
                    Label("Submitted", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if assignment.isOverdue {
                    Label("Overdue", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 12)

            if let dueDate = assignment.dueDate {
                Text(dueDate, format: .dateTime.hour().minute())
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("No due date")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let dueDescription = assignment.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "no due date"
        return "\(assignment.courseCode), \(assignment.title), \(dueDescription), \(assignment.status.rawValue)"
    }
}
