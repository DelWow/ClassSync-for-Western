import AppKit
import CryptoKit
import Foundation
import PDFKit

enum SyllabusImportError: LocalizedError, Equatable {
    case unsupportedFile
    case unreadableDocument
    case noText
    case noDatedItems

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            "Choose a PDF, Word, RTF, or plain-text syllabus."
        case .unreadableDocument:
            "ClassSync could not read this syllabus. Try exporting it as a text-based PDF."
        case .noText:
            "This syllabus does not contain selectable text. Scanned documents need OCR before importing."
        case .noDatedItems:
            "No assignment-like rows with recognizable dates were found."
        }
    }
}

struct SyllabusImportService: Sendable {
    private static let supportedExtensions: Set<String> = ["pdf", "txt", "text", "rtf", "rtfd", "doc", "docx"]
    private static let itemKeywords = [
        "assignment", "quiz", "lab", "project", "report", "essay", "paper",
        "midterm", "exam", "test", "presentation", "discussion", "proposal",
        "reflection", "problem set", "homework", "case study", "worksheet",
        "tutorial", "deliverable", "milestone", "assessment"
    ]

    func load(url: URL, now: Date = Date()) throws -> SyllabusImportResult {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let ext = url.pathExtension.lowercased()
        guard Self.supportedExtensions.contains(ext) else {
            throw SyllabusImportError.unsupportedFile
        }

        let text: String
        if ext == "pdf" {
            guard let document = PDFDocument(url: url) else {
                throw SyllabusImportError.unreadableDocument
            }
            text = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n")
        } else if ext == "txt" || ext == "text" {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
                throw SyllabusImportError.unreadableDocument
            }
            text = contents
        } else {
            guard let attributed = try? NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            ) else {
                throw SyllabusImportError.unreadableDocument
            }
            text = attributed.string
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SyllabusImportError.noText
        }
        return try parse(text: text, filename: url.deletingPathExtension().lastPathComponent, now: now)
    }

    func parse(text: String, filename: String, now: Date = Date()) throws -> SyllabusImportResult {
        let lines = text
            .components(separatedBy: .newlines)
            .map(Self.cleanWhitespace)
            .filter { !$0.isEmpty }

        let courseCode = Self.detectCourseCode(in: lines.joined(separator: "\n")) ?? "COURSE"
        let courseName = Self.detectCourseName(lines: lines, courseCode: courseCode, fallback: filename)
        let dateParser = AcademicDateParser()
        var drafts: [SyllabusAssignmentDraft] = []
        var fingerprints: Set<String> = []

        for row in Self.candidateRows(from: Array(lines.prefix(2_000)), dateParser: dateParser, now: now) {
            for match in dateParser.matches(in: row, now: now) {
                var dueDate = match.date
                if !match.hasExplicitTime {
                    dueDate = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: dueDate) ?? dueDate
                }
                let title = Self.detectTitle(in: row, dateRange: match.range)
                guard title.count >= 2, Self.looksLikeAssessment(title) else { continue }

                let fingerprint = "\(Self.normalizedFingerprint(title))|\(Int(dueDate.timeIntervalSince1970 / 60))"
                guard fingerprints.insert(fingerprint).inserted else { continue }
                drafts.append(SyllabusAssignmentDraft(title: title, dueDate: dueDate))
                if drafts.count == 150 { break }
            }
            if drafts.count == 150 { break }
        }

        guard !drafts.isEmpty else { throw SyllabusImportError.noDatedItems }
        var warnings: [String] = []
        if courseCode == "COURSE" {
            warnings.append("A course code was not detected. Review it before importing.")
        }
        let staleBoundary = Calendar.current.date(byAdding: .day, value: -45, to: now) ?? now
        let staleCount = drafts.filter { $0.dueDate < staleBoundary }.count
        if staleCount > 0 {
            warnings.append("\(staleCount) detected date\(staleCount == 1 ? " is" : "s are") well in the past. Confirm the syllabus year or use Move Past Dates Forward before importing.")
        }

        return SyllabusImportResult(
            courseCode: courseCode,
            courseName: courseName,
            drafts: drafts.sorted { $0.dueDate < $1.dueDate },
            warnings: warnings
        )
    }

    func makeModels(from result: SyllabusImportResult, importedAt: Date = Date()) -> (Course, [Assignment]) {
        let code = Self.cleanWhitespace(result.courseCode).uppercased()
        let name = Self.cleanWhitespace(result.courseName)
        let courseExternalID = Self.digest("syllabus-course|\(code)")
        let courseID = Course.stableID(source: .syllabus, externalID: courseExternalID)
        let course = Course(
            id: courseID,
            externalID: courseExternalID,
            code: code,
            name: name,
            source: .syllabus,
            isActive: true,
            colorHex: nil
        )

        var titleOccurrences: [String: Int] = [:]
        let assignments = result.drafts
            .filter { $0.isSelected && !Self.cleanWhitespace($0.title).isEmpty }
            .map { draft in
                let title = Self.cleanWhitespace(draft.title)
                let normalizedTitle = Self.normalizedFingerprint(title)
                let occurrence = titleOccurrences[normalizedTitle, default: 0]
                titleOccurrences[normalizedTitle] = occurrence + 1
                let identity = "\(code)|\(normalizedTitle)|\(occurrence)"
                let externalID = Self.digest(identity)
                return Assignment(
                    id: Assignment.stableID(source: .syllabus, externalID: externalID),
                    externalID: externalID,
                    courseID: courseID,
                    courseName: name,
                    courseCode: code,
                    title: title,
                    dueDate: draft.dueDate,
                    source: .syllabus,
                    url: nil,
                    status: draft.dueDate < importedAt ? .overdue : .upcoming,
                    createdAt: importedAt,
                    updatedAt: importedAt
                )
            }
        return (course, assignments)
    }

    private static func looksLikeAssessment(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return itemKeywords.contains { lowercased.contains($0) }
    }

    private static func candidateRows(
        from lines: [String],
        dateParser: AcademicDateParser,
        now: Date
    ) -> [String] {
        var rows: [String] = []
        var seen: Set<String> = []

        func append(_ value: String) {
            let cleaned = cleanWhitespace(value)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return }
            rows.append(cleaned)
        }

        for index in lines.indices {
            let line = lines[index]
            let hasAssessment = looksLikeAssessment(line)
            let hasDate = !dateParser.matches(in: line, now: now).isEmpty
            if hasAssessment && hasDate { append(line) }

            if hasAssessment && !hasDate {
                if let neighbor = [index + 1, index - 1, index + 2, index - 2].first(where: {
                    lines.indices.contains($0) && !dateParser.matches(in: lines[$0], now: now).isEmpty
                }) {
                    append("\(line) | \(lines[neighbor])")
                }
            } else if hasDate && !hasAssessment {
                if let neighbor = [index - 1, index + 1, index - 2, index + 2].first(where: {
                    lines.indices.contains($0) && looksLikeAssessment(lines[$0])
                }) {
                    append("\(lines[neighbor]) | \(line)")
                }
            }
        }
        return rows
    }

    private static func detectCourseCode(in text: String) -> String? {
        let pattern = #"(?i)\b([A-Z]{2,8})\s*[- ]?\s*(\d{3,4}[A-Z]?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let subjectRange = Range(match.range(at: 1), in: text),
              let numberRange = Range(match.range(at: 2), in: text)
        else { return nil }
        return "\(text[subjectRange].uppercased()) \(text[numberRange].uppercased())"
    }

    private static func detectCourseName(lines: [String], courseCode: String, fallback: String) -> String {
        if courseCode != "COURSE" {
            let compactCode = courseCode.replacingOccurrences(of: " ", with: "")
            if let line = lines.prefix(30).first(where: {
                $0.uppercased().replacingOccurrences(of: " ", with: "").contains(compactCode)
            }) {
                let name = line
                    .replacingOccurrences(of: courseCode, with: "", options: [.caseInsensitive])
                    .trimmingCharacters(in: CharacterSet(charactersIn: "-–—:| "))
                if name.count >= 3 { return name }
            }
        }
        let cleanedFallback = cleanWhitespace(fallback)
        return cleanedFallback.isEmpty ? "Imported Syllabus" : cleanedFallback
    }

    private static func detectTitle(in line: String, dateRange: NSRange) -> String {
        let nsLine = line as NSString
        var prefix = nsLine.substring(to: max(0, dateRange.location))
        if let dueRange = prefix.range(of: #"(?i)\b(?:is\s+)?due\b"#, options: .regularExpression) {
            prefix = String(prefix[..<dueRange.lowerBound])
        }
        var trimmed = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "•·-–—:| \t"))
        if let separator = trimmed.lastIndex(of: "|") {
            trimmed = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !trimmed.isEmpty { return cleanTitle(trimmed) }

        let withoutDate = nsLine.replacingCharacters(in: dateRange, with: "")
        return cleanTitle(withoutDate)
    }

    private static func cleanTitle(_ value: String) -> String {
        cleanWhitespace(value)
            .replacingOccurrences(of: #"(?i)\b(?:due|deadline|date)\s*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+\d{1,3}(?:\.\d+)?%\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "•·-–—:| []()\t"))
    }

    private static func normalizedFingerprint(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
    }

    private static func cleanWhitespace(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
