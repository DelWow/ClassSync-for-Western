import AppKit
import CryptoKit
import Foundation

enum SchoolEmailError: LocalizedError, Equatable {
    case mailUnavailable
    case permissionDenied
    case noWesternAccount
    case unreadableMailbox

    var errorDescription: String? {
        switch self {
        case .mailUnavailable:
            "Apple Mail is not available on this Mac."
        case .permissionDenied:
            "ClassSync cannot read Apple Mail. Allow access in System Settings → Privacy & Security → Automation."
        case .noWesternAccount:
            "No @uwo.ca or @westernu.ca account was found in Apple Mail. Add the account there first."
        case .unreadableMailbox:
            "ClassSync could not read recent messages from the Western inbox in Apple Mail."
        }
    }
}

actor AppleMailMessageService {
    func recentWesternMessages(limit: Int = 75) throws -> [SchoolEmailMessage] {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail") != nil else {
            throw SchoolEmailError.mailUnavailable
        }
        let safeLimit = min(max(limit, 1), 150)
        let source = """
        set outputRows to {}
        set foundWesternAccount to false
        tell application "Mail"
            repeat with mailAccount in every account
                set accountMatches to false
                set accountAddress to ""
                try
                    repeat with candidateAddress in (email addresses of mailAccount)
                        set addressText to contents of candidateAddress
                        if addressText ends with "@uwo.ca" or addressText ends with "@westernu.ca" then
                            set accountMatches to true
                            set accountAddress to addressText
                            exit repeat
                        end if
                    end repeat
                end try
                if accountMatches then
                    set foundWesternAccount to true
                    repeat with candidateMailbox in (mailboxes of mailAccount)
                        set mailboxName to name of candidateMailbox
                        if mailboxName is "Inbox" or mailboxName is "INBOX" then
                            set availableCount to count of messages of candidateMailbox
                            if availableCount > \(safeLimit) then
                                set takeCount to \(safeLimit)
                            else
                                set takeCount to availableCount
                            end if
                            repeat with messageIndex from 1 to takeCount
                                try
                                    set currentMessage to message messageIndex of candidateMailbox
                                    set messageIdentifier to message id of currentMessage
                                    if messageIdentifier is missing value then set messageIdentifier to (id of currentMessage as text)
                                    set messageSubject to subject of currentMessage
                                    if messageSubject is missing value then set messageSubject to ""
                                    set messageSender to sender of currentMessage
                                    if messageSender is missing value then set messageSender to ""
                                    set messageBody to content of currentMessage
                                    if messageBody is missing value then set messageBody to ""
                                    if (length of messageBody) > 20000 then set messageBody to text 1 thru 20000 of messageBody
                                    set end of outputRows to {accountAddress & ":" & (messageIdentifier as text), messageSubject as text, messageSender as text, messageBody as text}
                                end try
                            end repeat
                        end if
                    end repeat
                end if
            end repeat
        end tell
        if foundWesternAccount is false then return {{"__NO_WESTERN_ACCOUNT__", "", "", ""}}
        return outputRows
        """

        guard let script = NSAppleScript(source: source) else {
            throw SchoolEmailError.unreadableMailbox
        }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let number = errorInfo?[NSAppleScript.errorNumber] as? Int, number == -1743 {
            throw SchoolEmailError.permissionDenied
        }
        guard errorInfo == nil, result.numberOfItems > 0 else {
            if errorInfo == nil { return [] }
            AppLogger.email.error("Apple Mail scan failed with an AppleScript error")
            throw SchoolEmailError.unreadableMailbox
        }

        var messages: [SchoolEmailMessage] = []
        for index in 1...result.numberOfItems {
            guard let row = result.atIndex(index), row.numberOfItems >= 4 else { continue }
            let identifier = row.atIndex(1)?.stringValue ?? ""
            if identifier == "__NO_WESTERN_ACCOUNT__" { throw SchoolEmailError.noWesternAccount }
            guard !identifier.isEmpty else { continue }
            messages.append(
                SchoolEmailMessage(
                    id: identifier,
                    subject: row.atIndex(2)?.stringValue ?? "",
                    sender: row.atIndex(3)?.stringValue ?? "",
                    body: row.atIndex(4)?.stringValue ?? ""
                )
            )
        }
        return messages
    }
}

struct EmailDeadlineChangeDetector: Sendable {
    private static let changePhrases = [
        "due date", "deadline", "extended", "extension", "moved to", "postponed",
        "now due", "new date", "date changed", "rescheduled", "submit by"
    ]
    private static let ignoredWords: Set<String> = [
        "assignment", "project", "report", "paper", "quiz", "test", "exam", "midterm",
        "final", "course", "your", "this", "that", "with", "from", "into", "submission"
    ]

    func detect(
        messages: [SchoolEmailMessage],
        assignments: [Assignment],
        courses: [Course],
        processedMessageIDs: Set<String> = [],
        now: Date = Date()
    ) -> [EmailDeadlineSuggestion] {
        let dateParser = AcademicDateParser()
        var suggestions: [EmailDeadlineSuggestion] = []

        for message in messages where !processedMessageIDs.contains(message.id) {
            let text = "\(message.subject)\n\(message.body)"
            let lowercased = text.lowercased()
            guard Self.changePhrases.contains(where: lowercased.contains) else { continue }
            guard let dateMatch = dateParser.matches(in: text, now: now).last else { continue }
            var proposedDate = dateMatch.date

            let matchedCourses = courses.filter { course in
                let compactText = lowercased.replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
                let compactCode = course.code.lowercased().replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
                return compactCode.count >= 4 && compactText.contains(compactCode)
            }
            let candidates = assignments.filter { assignment in
                matchedCourses.isEmpty || matchedCourses.contains { $0.id == assignment.courseID || $0.code.caseInsensitiveCompare(assignment.courseCode) == .orderedSame }
            }
            guard let assignment = bestAssignmentMatch(in: candidates, text: lowercased) else { continue }

            if !dateMatch.hasExplicitTime {
                var calendar = Calendar.current
                calendar.timeZone = .current
                if let previous = assignment.dueDate {
                    let time = calendar.dateComponents([.hour, .minute, .second], from: previous)
                    proposedDate = calendar.date(
                        bySettingHour: time.hour ?? 23,
                        minute: time.minute ?? 59,
                        second: time.second ?? 0,
                        of: proposedDate
                    ) ?? proposedDate
                } else {
                    proposedDate = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: proposedDate) ?? proposedDate
                }
            }
            if let oldDate = assignment.dueDate,
               abs(oldDate.timeIntervalSince(proposedDate)) < 60 { continue }

            let suggestionID = digest("\(message.id)|\(assignment.id)|\(Int(proposedDate.timeIntervalSince1970 / 60))")
            suggestions.append(
                EmailDeadlineSuggestion(
                    id: suggestionID,
                    messageID: message.id,
                    assignmentID: assignment.id,
                    courseCode: assignment.courseCode,
                    assignmentTitle: assignment.title,
                    previousDueDate: assignment.dueDate,
                    proposedDueDate: proposedDate,
                    emailSubject: message.subject,
                    sender: message.sender
                )
            )
        }

        return suggestions.uniqued(on: \.id).sorted { $0.proposedDueDate < $1.proposedDueDate }
    }

    private func bestAssignmentMatch(in assignments: [Assignment], text: String) -> Assignment? {
        assignments
            .map { assignment -> (Assignment, Int) in
                let title = assignment.title.lowercased()
                let exactBonus = text.contains(title) ? 20 : 0
                let meaningfulTokens = tokenize(title).subtracting(Self.ignoredWords)
                let score = exactBonus + meaningfulTokens.filter(text.contains).count
                return (assignment, score)
            }
            .filter { $0.1 > 0 }
            .max { lhs, rhs in lhs.1 < rhs.1 }?.0
    }

    private func tokenize(_ value: String) -> Set<String> {
        Set(value.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 3 })
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension Sequence {
    func uniqued<ID: Hashable>(on keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen: Set<ID> = []
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
