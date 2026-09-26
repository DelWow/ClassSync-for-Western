import Foundation

struct AcademicDateMatch: Equatable, Sendable {
    let range: NSRange
    let date: Date
    let hasExplicitTime: Bool
    let hasExplicitYear: Bool
}

struct AcademicDateParser: Sendable {
    private static let monthPattern = #"(?i)\b(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s*,?\s*(\d{4}))?(?:\s*(?:,|at|@)?\s*(?:(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)|(\d{1,2}):(\d{2})))?\b"#
    private static let dayFirstPattern = #"(?i)\b(\d{1,2})(?:st|nd|rd|th)?\s+(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?(?:\s*,?\s*(\d{4}))?(?:\s*(?:,|at|@)?\s*(?:(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)|(\d{1,2}):(\d{2})))?\b"#
    private static let numericPattern = #"\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?(?:\s*(?:,|at|@)?\s*(?:(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)|(\d{1,2}):(\d{2})))?\b"#
    private static let isoPattern = #"\b(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{1,2}):?(\d{2})?\s*(a\.?m\.?|p\.?m\.?)?)?\b"#

    func matches(in text: String, now: Date = Date(), timeZone: TimeZone = .current) -> [AcademicDateMatch] {
        var matches: [AcademicDateMatch] = []
        matches.append(contentsOf: parseMonthNames(in: text, now: now, timeZone: timeZone))
        matches.append(contentsOf: parseDayFirstMonthNames(in: text, now: now, timeZone: timeZone))
        matches.append(contentsOf: parseNumeric(in: text, now: now, timeZone: timeZone))
        matches.append(contentsOf: parseISO(in: text, now: now, timeZone: timeZone))

        return matches
            .sorted { $0.range.location < $1.range.location }
            .reduce(into: []) { result, match in
                guard !result.contains(where: { NSIntersectionRange($0.range, match.range).length > 0 }) else { return }
                result.append(match)
            }
    }

    private func parseMonthNames(in text: String, now: Date, timeZone: TimeZone) -> [AcademicDateMatch] {
        guard let regex = try? NSRegularExpression(pattern: Self.monthPattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let monthText = capture(1, match: match, in: text),
                  let month = monthNumber(monthText),
                  let day = captureInt(2, match: match, in: text)
            else { return nil }
            let year = captureInt(3, match: match, in: text)
            let hour = captureInt(4, match: match, in: text) ?? captureInt(7, match: match, in: text)
            let minute = captureInt(5, match: match, in: text) ?? captureInt(8, match: match, in: text) ?? 0
            let marker = capture(6, match: match, in: text)
            return makeMatch(
                range: match.range,
                year: year,
                month: month,
                day: day,
                hour: normalizedHour(hour, marker: marker),
                minute: minute,
                hasExplicitTime: hour != nil,
                hasExplicitYear: year != nil,
                now: now,
                timeZone: timeZone
            )
        }
    }

    private func parseDayFirstMonthNames(in text: String, now: Date, timeZone: TimeZone) -> [AcademicDateMatch] {
        guard let regex = try? NSRegularExpression(pattern: Self.dayFirstPattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let day = captureInt(1, match: match, in: text),
                  let monthText = capture(2, match: match, in: text),
                  let month = monthNumber(monthText)
            else { return nil }
            let year = captureInt(3, match: match, in: text)
            let hour = captureInt(4, match: match, in: text) ?? captureInt(7, match: match, in: text)
            return makeMatch(
                range: match.range,
                year: year,
                month: month,
                day: day,
                hour: normalizedHour(hour, marker: capture(6, match: match, in: text)),
                minute: captureInt(5, match: match, in: text) ?? captureInt(8, match: match, in: text) ?? 0,
                hasExplicitTime: hour != nil,
                hasExplicitYear: year != nil,
                now: now,
                timeZone: timeZone
            )
        }
    }

    private func parseNumeric(in text: String, now: Date, timeZone: TimeZone) -> [AcademicDateMatch] {
        guard let regex = try? NSRegularExpression(pattern: Self.numericPattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard var first = captureInt(1, match: match, in: text),
                  var second = captureInt(2, match: match, in: text)
            else { return nil }
            var year = captureInt(3, match: match, in: text)
            if year == nil, !isLikelyYearlessNumeric(match: match, in: text) { return nil }
            if let shortYear = year, shortYear < 100 {
                year = shortYear + (shortYear >= 70 ? 1900 : 2000)
            }
            if first > 12, second <= 12 { swap(&first, &second) }
            let hour = captureInt(4, match: match, in: text) ?? captureInt(7, match: match, in: text)
            return makeMatch(
                range: match.range,
                year: year,
                month: first,
                day: second,
                hour: normalizedHour(hour, marker: capture(6, match: match, in: text)),
                minute: captureInt(5, match: match, in: text) ?? captureInt(8, match: match, in: text) ?? 0,
                hasExplicitTime: hour != nil,
                hasExplicitYear: year != nil,
                now: now,
                timeZone: timeZone
            )
        }
    }

    private func parseISO(in text: String, now: Date, timeZone: TimeZone) -> [AcademicDateMatch] {
        guard let regex = try? NSRegularExpression(pattern: Self.isoPattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let year = captureInt(1, match: match, in: text),
                  let month = captureInt(2, match: match, in: text),
                  let day = captureInt(3, match: match, in: text)
            else { return nil }
            let hour = captureInt(4, match: match, in: text)
            return makeMatch(
                range: match.range,
                year: year,
                month: month,
                day: day,
                hour: normalizedHour(hour, marker: capture(6, match: match, in: text)),
                minute: captureInt(5, match: match, in: text) ?? 0,
                hasExplicitTime: hour != nil,
                hasExplicitYear: true,
                now: now,
                timeZone: timeZone
            )
        }
    }

    private func makeMatch(
        range: NSRange,
        year: Int?,
        month: Int,
        day: Int,
        hour: Int?,
        minute: Int,
        hasExplicitTime: Bool,
        hasExplicitYear: Bool,
        now: Date,
        timeZone: TimeZone
    ) -> AcademicDateMatch? {
        guard (1...12).contains(month),
              (1...31).contains(day),
              (0...59).contains(minute),
              hour.map({ (0...23).contains($0) }) ?? true
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var resolvedYear = year ?? calendar.component(.year, from: now)
        var components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: resolvedYear,
            month: month,
            day: day,
            hour: hour ?? 0,
            minute: minute
        )
        guard var date = calendar.date(from: components),
              calendar.component(.month, from: date) == month,
              calendar.component(.day, from: date) == day
        else { return nil }

        if year == nil,
           let recentPastBoundary = calendar.date(byAdding: .day, value: -45, to: now),
           date < recentPastBoundary {
            resolvedYear += 1
            components.year = resolvedYear
            guard let adjusted = calendar.date(from: components) else { return nil }
            date = adjusted
        }
        return AcademicDateMatch(
            range: range,
            date: date,
            hasExplicitTime: hasExplicitTime,
            hasExplicitYear: hasExplicitYear
        )
    }

    private func isLikelyYearlessNumeric(match: NSTextCheckingResult, in text: String) -> Bool {
        let nsText = text as NSString
        let start = max(0, match.range.location - 32)
        let end = min(nsText.length, NSMaxRange(match.range) + 32)
        let context = nsText.substring(with: NSRange(location: start, length: end - start)).lowercased()
        return ["due", "deadline", "date", "assignment", "quiz", "exam", "test", "project", "lab"]
            .contains(where: context.contains)
    }

    private func capture(_ index: Int, match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private func captureInt(_ index: Int, match: NSTextCheckingResult, in text: String) -> Int? {
        capture(index, match: match, in: text).flatMap(Int.init)
    }

    private func monthNumber(_ value: String) -> Int? {
        switch value.lowercased().prefix(3) {
        case "jan": 1
        case "feb": 2
        case "mar": 3
        case "apr": 4
        case "may": 5
        case "jun": 6
        case "jul": 7
        case "aug": 8
        case "sep": 9
        case "oct": 10
        case "nov": 11
        case "dec": 12
        default: nil
        }
    }

    private func normalizedHour(_ hour: Int?, marker: String?) -> Int? {
        guard var hour else { return nil }
        guard let marker else { return hour }
        let normalized = marker.lowercased().replacingOccurrences(of: ".", with: "")
        guard (1...12).contains(hour) else { return nil }
        if normalized == "pm", hour < 12 { hour += 12 }
        if normalized == "am", hour == 12 { hour = 0 }
        return hour
    }
}
