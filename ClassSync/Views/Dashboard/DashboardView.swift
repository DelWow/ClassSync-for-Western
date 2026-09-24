import SwiftUI

private enum DashboardSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case upcoming = "Upcoming"
    case calendar = "Calendar"
    case changes = "Changes"
    case courses = "Courses"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .upcoming: "list.bullet"
        case .calendar: "calendar"
        case .changes: "clock.arrow.circlepath"
        case .courses: "books.vertical"
        case .settings: "gearshape"
        }
    }
}

struct DashboardView: View {
    @ObservedObject var appModel: AppModel

    @State private var selection: DashboardSection? = .upcoming
    @State private var searchText = ""
    @State private var selectedCourseID = "all"

    var body: some View {
        NavigationSplitView {
            List(DashboardSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("ClassSync")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            detail(for: selection ?? .upcoming)
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    @ViewBuilder
    private func detail(for section: DashboardSection) -> some View {
        switch section {
        case .today:
            assignmentList(
                title: "Today",
                assignments: filteredAssignments.filter { assignment in
                    assignment.dueDate.map(Calendar.current.isDateInToday) == true
                }
            )
        case .upcoming:
            assignmentList(title: "Upcoming", assignments: filteredAssignments)
        case .calendar:
            AssignmentCalendarView(assignments: appModel.assignments)
        case .changes:
            ChangeHistoryView(changes: appModel.changes)
        case .courses:
            CourseListView(courses: appModel.courses)
        case .settings:
            SettingsContentView(courses: appModel.courses)
                .navigationTitle("Settings")
        }
    }

    private var filteredAssignments: [Assignment] {
        appModel.assignments.filter { assignment in
            let matchesCourse = selectedCourseID == "all" || assignment.courseID == selectedCourseID
            let matchesSearch = searchText.isEmpty
                || assignment.title.localizedCaseInsensitiveContains(searchText)
                || assignment.courseCode.localizedCaseInsensitiveContains(searchText)
            return matchesCourse && matchesSearch
        }
    }

    private func assignmentList(title: String, assignments: [Assignment]) -> some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Course", selection: $selectedCourseID) {
                    Text("All Courses").tag("all")
                    ForEach(appModel.courses) { course in
                        Text(course.code).tag(course.id)
                    }
                }
                .frame(maxWidth: 240)

                Spacer()

                Button {
                    Task { await appModel.syncNow() }
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(appModel.syncState == .syncing)
            }
            .padding()

            Divider()

            if assignments.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(assignments) { assignment in
                    AssignmentRow(assignment: assignment)
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search assignments or courses")
    }
}

private struct AssignmentCalendarView: View {
    let assignments: [Assignment]
    @State private var selectedDate = Date()

    private var assignmentsForDate: [Assignment] {
        assignments.filter { assignment in
            assignment.dueDate.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } == true
        }
    }

    var body: some View {
        HSplitView {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .frame(minWidth: 300)

            VStack(alignment: .leading) {
                Text(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.title2.weight(.semibold))
                    .padding([.top, .horizontal])

                if assignmentsForDate.isEmpty {
                    ContentUnavailableView("No Assignments", systemImage: "calendar", description: Text("Nothing is due on this date."))
                } else {
                    List(assignmentsForDate) { AssignmentRow(assignment: $0) }
                }
            }
            .frame(minWidth: 320)
        }
        .navigationTitle("Calendar")
    }
}

private struct ChangeHistoryView: View {
    let changes: [AssignmentChange]

    var body: some View {
        Group {
            if changes.isEmpty {
                ContentUnavailableView("No Changes Yet", systemImage: "clock.arrow.circlepath", description: Text("Detected assignment changes will appear here."))
            } else {
                List(changes) { change in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(change.courseCode) — \(change.assignmentTitle)")
                            .font(.headline)
                        Text(change.changeType.rawValue.capitalized)
                            .font(.callout)
                        if change.oldValue != nil || change.newValue != nil {
                            Text("\(change.oldValue ?? "None") → \(change.newValue ?? "None")")
                                .foregroundStyle(.secondary)
                        }
                        Text(change.detectedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Recent Changes")
    }
}

private struct CourseListView: View {
    let courses: [Course]

    var body: some View {
        List(courses) { course in
            VStack(alignment: .leading, spacing: 4) {
                Text(course.code).font(.headline)
                Text(course.name).foregroundStyle(.secondary)
                Text(course.source.displayName).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Courses")
    }
}

