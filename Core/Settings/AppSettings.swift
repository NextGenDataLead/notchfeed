import Foundation

/// Settings live in UserDefaults (see DECISIONS.md); these are the keys and their PRD defaults.
public enum AppSettings {
    public enum Key {
        public static let tickerPosition = "tickerPosition"
        /// `CGDirectDisplayID` of the chosen display; 0 means the primary display.
        public static let tickerDisplayID = "tickerDisplayID"
        /// Name of the chosen display, shown while it isn't connected.
        public static let tickerDisplayName = "tickerDisplayName"
        public static let showFeedName = "showFeedName"
        public static let showUnreadCount = "showUnreadCount"
        public static let retentionDays = "retentionDays"
    }

    public static let retentionRange = 1...365

    public static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.tickerPosition: AppDefaults.tickerPosition.rawValue,
            Key.tickerDisplayID: 0,
            Key.showFeedName: AppDefaults.showFeedName,
            Key.showUnreadCount: AppDefaults.showUnreadCount,
            Key.retentionDays: AppDefaults.retentionDays,
        ])
    }

    public static func tickerPosition(in defaults: UserDefaults = .standard) -> TickerPosition {
        defaults.string(forKey: Key.tickerPosition).flatMap(TickerPosition.init(rawValue:)) ?? AppDefaults.tickerPosition
    }

    /// nil means "primary display".
    public static func tickerDisplayID(in defaults: UserDefaults = .standard) -> UInt32? {
        let value = defaults.integer(forKey: Key.tickerDisplayID)
        return value > 0 ? UInt32(clamping: value) : nil
    }

    public static func retentionDays(in defaults: UserDefaults = .standard) -> Int {
        let value = defaults.integer(forKey: Key.retentionDays)
        return value == 0 ? AppDefaults.retentionDays : min(max(value, retentionRange.lowerBound), retentionRange.upperBound)
    }
}
