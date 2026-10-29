import Foundation

/// FR-1.8: an item's age in the coarse steps the ticker shows ("now", "5m", "3h", "2d").
/// The app turns it into a localised string.
public enum RelativeAge: Sendable, Equatable, Hashable {
    case justNow
    case minutes(Int)
    case hours(Int)
    case days(Int)

    public init(of date: Date, now: Date) {
        let seconds = Int(now.timeIntervalSince(date))
        switch seconds {
        case ..<60: self = .justNow
        case ..<3600: self = .minutes(seconds / 60)
        case ..<86_400: self = .hours(seconds / 3600)
        default: self = .days(seconds / 86_400)
        }
    }
}
