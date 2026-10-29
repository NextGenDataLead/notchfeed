import Foundation

/// Lenient parser for feed dates: RFC 822 variants (RSS) and ISO 8601 variants (Atom, dc:date).
/// Missing time zones are read as UTC; fractional seconds are dropped.
public struct DateParser: Sendable {
    public init() {}

    public func date(from string: String) -> Date? {
        let trimmed = string.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !trimmed.isEmpty else { return nil }
        if trimmed.first?.isNumber == true, let date = iso8601(trimmed) {
            return date
        }
        return rfc822(trimmed)
    }

    // MARK: ISO 8601

    private func iso8601(_ string: String) -> Date? {
        let pattern = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[Tt ](\d{1,2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)? ?(Z|z|[+-]\d{2}(?::?\d{2})?)?$/
        guard let match = string.wholeMatch(of: pattern) else { return nil }
        let output = match.output
        let offset = output.7.flatMap { Self.numericOffset(String($0)) } ?? 0
        return Self.makeDate(
            year: Int(output.1), month: Int(output.2), day: Int(output.3),
            hour: output.4.flatMap { Int($0) } ?? 0,
            minute: output.5.flatMap { Int($0) } ?? 0,
            second: output.6.flatMap { Int($0) } ?? 0,
            offset: offset
        )
    }

    // MARK: RFC 822

    private func rfc822(_ string: String) -> Date? {
        // Drop an optional weekday ("Tue," or "Tuesday,").
        var rest = Substring(string)
        if let comma = rest.firstIndex(of: ",") {
            rest = rest[rest.index(after: comma)...]
        }
        let tokens = rest.split(separator: " ")
        guard tokens.count >= 4 else { return nil }

        guard let month = Self.month(String(tokens[1])) else { return nil }
        guard var year = Int(tokens[2]) else { return nil }
        if tokens[2].count == 2 { year += 2000 }

        let time = tokens[3].split(separator: ":").map { Int($0) }
        guard time.count >= 2, time.allSatisfy({ $0 != nil }) else { return nil }

        let offset = tokens.count >= 5 ? Self.zoneOffset(String(tokens[4])) : 0
        return Self.makeDate(
            year: year, month: month, day: Int(tokens[0]),
            hour: time[0] ?? 0, minute: time[1] ?? 0, second: time.count > 2 ? time[2] ?? 0 : 0,
            offset: offset
        )
    }

    private static let months: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
        // Dutch abbreviations that differ from English.
        "mrt": 3, "mei": 5, "okt": 10,
    ]

    private static func month(_ token: String) -> Int? {
        months[String(token.lowercased().prefix(3))]
    }

    private static let namedZones: [String: Int] = [
        "UT": 0, "UTC": 0, "GMT": 0, "Z": 0,
        "EST": -5, "EDT": -4, "CST": -6, "CDT": -5,
        "MST": -7, "MDT": -6, "PST": -8, "PDT": -7,
        "CET": 1, "CEST": 2,
    ]

    /// Offset in seconds; unknown zone names fall back to UTC.
    private static func zoneOffset(_ token: String) -> Int {
        if let hours = namedZones[token.uppercased()] { return hours * 3600 }
        return numericOffset(token) ?? 0
    }

    /// Parses "+0100", "+01:00", "+01" and "Z".
    private static func numericOffset(_ token: String) -> Int? {
        if token == "Z" || token == "z" { return 0 }
        guard let sign = token.first, sign == "+" || sign == "-" else { return nil }
        let digits = token.dropFirst().filter(\.isNumber)
        guard digits.count == 2 || digits.count == 4,
              let hours = Int(digits.prefix(2)),
              let minutes = digits.count == 4 ? Int(digits.suffix(2)) : 0,
              hours <= 14, minutes < 60 else { return nil }
        let seconds = hours * 3600 + minutes * 60
        return sign == "-" ? -seconds : seconds
    }

    // MARK: Building

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private static func makeDate(year: Int?, month: Int?, day: Int?, hour: Int, minute: Int, second: Int, offset: Int) -> Date? {
        guard let year, let month, let day,
              (1970...2200).contains(year), (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second) else { return nil }
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: min(second, 59))
        guard let local = utcCalendar.date(from: components),
              utcCalendar.component(.day, from: local) == day else { return nil } // rejects 31 Feb etc.
        return local.addingTimeInterval(TimeInterval(-offset))
    }
}
