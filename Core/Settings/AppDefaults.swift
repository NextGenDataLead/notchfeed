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
}

public enum TickerPosition: String, Sendable, CaseIterable {
    case top
    case bottom
}
