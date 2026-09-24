import SwiftUI

private enum DashboardSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case upcoming = "Upcoming"
    case calendar = "Calendar"
    case changes = "Changes"
    case courses = "Courses"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .upcoming: "list.bullet"
        case .calendar: "calendar"
        case .changes: "clock.arrow.circlepath"
        case .courses: "books.vertical"
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
            AssignmentCalendarView(appModel: appModel)
        case .changes:
            ChangeHistoryView(appModel: appModel)
        case .courses:
            CourseListView(appModel: appModel)
        }
    }

    private var filteredAssignments: [Assignment] {
        appModel.visibleAssignments.filter { assignment in
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
                    AssignmentRow(
                        assignment: assignment,
                        courseColorHex: appModel.colorHex(for: assignment.courseID)
                    )
                        .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search assignments or courses")
    }
}

private struct AssignmentCalendarView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedDate = Date()

    private var assignmentsForDate: [Assignment] {
        appModel.visibleAssignments.filter { assignment in
            assignment.dueDate.map { Calendar.current.isDate($0, inSameDayAs: selectedDate) } == true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            AssignmentDateIndicators(
                assignments: appModel.visibleAssignments,
                selectedDate: $selectedDate,
                colorHex: appModel.colorHex(for:)
            )

            Divider()

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
                        List(assignmentsForDate) { assignment in
                            AssignmentRow(
                                assignment: assignment,
                                courseColorHex: appModel.colorHex(for: assignment.courseID)
                            )
                        }
                    }
                }
                .frame(minWidth: 320)
            }
        }
        .navigationTitle("Calendar")
    }
}

private struct AssignmentDateIndicators: View {
    let assignments: [Assignment]
    @Binding var selectedDate: Date
    let colorHex: (String) -> String

    private var dates: [Date] {
        let calendar = Calendar.current
        return Array(
            Set(assignments.compactMap { $0.dueDate.map(calendar.startOfDay(for:)) })
        ).sorted()
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    let due = assignments.filter { assignment in
                        assignment.dueDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
                    }
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 5) {
                            Text(date, format: .dateTime.weekday(.abbreviated).day())
                                .font(.caption.weight(.medium))
                            HStack(spacing: 3) {
                                ForEach(due.prefix(4)) { assignment in
                                    Circle()
                                        .fill(Color(hex: colorHex(assignment.courseID)) ?? .secondary)
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                        .padding(8)
                        .background(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(date.formatted(date: .long, time: .omitted)), \(due.count) assignments")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

private struct ChangeHistoryView: View {
    @ObservedObject var appModel: AppModel
    @State private var courseID = "all"
    @State private var changeType = "all"
    @State private var days = 0

    private var filteredChanges: [AssignmentChange] {
        appModel.changes.filter { change in
            let courseMatches = courseID == "all" || change.courseID == courseID
            let typeMatches = changeType == "all" || change.changeType.rawValue == changeType
            let dateMatches = days == 0 || change.detectedAt >= Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            return courseMatches && typeMatches && dateMatches
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Course", selection: $courseID) {
                    Text("All Courses").tag("all")
                    ForEach(appModel.courses) { Text($0.code).tag($0.id) }
                }
                Picker("Change", selection: $changeType) {
                    Text("All Changes").tag("all")
                    ForEach(AssignmentChangeType.allCases, id: \.rawValue) { Text($0.rawValue.capitalized).tag($0.rawValue) }
                }
                Picker("Date", selection: $days) {
                    Text("All Time").tag(0)
                    Text("7 Days").tag(7)
                    Text("30 Days").tag(30)
                }
            }
            .padding()

            Divider()

            if filteredChanges.isEmpty {
                ContentUnavailableView("No Changes Yet", systemImage: "clock.arrow.circlepath", description: Text("Detected assignment changes will appear here."))
            } else {
                List(filteredChanges) { change in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color(hex: appModel.colorHex(for: change.courseID)) ?? .secondary)
                            .frame(width: 8, height: 8)
                            .padding(.top, 5)
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
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Recent Changes")
    }
}

private struct CourseListView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        List(appModel.courses) { course in
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: appModel.colorHex(for: course.id)) ?? .secondary)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.code).font(.headline)
                    Text(course.name).foregroundStyle(.secondary)
                    Text("\(course.source.displayName) • \(appModel.isCourseEnabled(course.id) ? "Enabled" : "Disabled")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Courses")
    }
}
