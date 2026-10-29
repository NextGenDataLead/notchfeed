import Foundation

/// Default values for every setting, as specified in the PRD.
public enum AppDefaults {
    /// FR-4.6: items older than this are purged.
    public static let retentionDays = 30
    /// FR-8.3 default; fixed in V0.1.
    public static let refreshInterval: Duration = .seconds(15 * 60)
    /// FR-8.5: maximum number of feed requests in flight.
    public static let maxParallelFetches = 6
    /// FR-1.2: the ticker sits under the menu bar by default.
    public static let tickerPosition = TickerPosition.top
    /// FR-1.8: the feed name is optional and shown by default.
    public static let showFeedName = true
    /// FR-5.1: the unread count is optional and shown by default.
    public static let showUnreadCount = true
    /// The ticker shows the newest items across all feeds (see DECISIONS.md).
    public static let tickerItemLimit = 50
    /// FR-5.2: the menu bar dropdown lists this many recent items.
    public static let menuItemLimit = 20
}

public enum TickerPosition: String, Sendable, CaseIterable {
    case top
    case bottom
}
