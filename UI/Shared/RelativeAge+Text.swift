import Foundation
import NotchFeedCore

extension RelativeAge {
    /// Compact form for the ticker and menu: "now", "5m", "3h", "2d".
    var shortText: String {
        switch self {
        case .justNow: String(localized: "now", comment: "Age of an item published less than a minute ago")
        case .minutes(let count): String(localized: "\(count)m", comment: "Age in minutes, compact")
        case .hours(let count): String(localized: "\(count)h", comment: "Age in hours, compact")
        case .days(let count): String(localized: "\(count)d", comment: "Age in days, compact")
        }
    }
}

enum SpokenAge {
    /// Full form for VoiceOver, such as "5 minutes ago".
    static func text(for date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
