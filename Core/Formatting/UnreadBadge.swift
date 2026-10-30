/// FR-5.1: what the menu bar badge shows. Large counts are capped ("99+") so the badge,
/// and with it the menu bar item, stays narrow enough to fit beside the notch.
public enum UnreadBadge: Equatable, Sendable {
    public static let maxCount = 99

    case count(Int)
    /// More than `maxCount`; shown as "99+".
    case overflow(Int)

    public init?(unread: Int) {
        guard unread > 0 else { return nil }
        self = unread > Self.maxCount ? .overflow(Self.maxCount) : .count(unread)
    }
}
