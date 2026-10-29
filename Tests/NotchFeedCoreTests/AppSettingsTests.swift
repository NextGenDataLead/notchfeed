import Foundation
import Testing
@testable import NotchFeedCore

struct AppSettingsTests {
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "AppSettingsTests-\(UUID().uuidString)"))
        AppSettings.registerDefaults(in: defaults)
    }

    @Test func registeredDefaultsMatchPRD() {
        #expect(AppSettings.tickerPosition(in: defaults) == .top)
        #expect(AppSettings.tickerDisplayID(in: defaults) == nil)
        #expect(AppSettings.retentionDays(in: defaults) == 30)
        #expect(defaults.bool(forKey: AppSettings.Key.showFeedName))
        #expect(defaults.bool(forKey: AppSettings.Key.showUnreadCount))
    }

    @Test func clampsRetentionAndIgnoresUnknownPosition() {
        defaults.set(5000, forKey: AppSettings.Key.retentionDays)
        #expect(AppSettings.retentionDays(in: defaults) == 365)
        defaults.set(-3, forKey: AppSettings.Key.retentionDays)
        #expect(AppSettings.retentionDays(in: defaults) == 1)
        defaults.set("sideways", forKey: AppSettings.Key.tickerPosition)
        #expect(AppSettings.tickerPosition(in: defaults) == .top)
    }

    @Test func readsChosenDisplay() {
        defaults.set(69_734_272, forKey: AppSettings.Key.tickerDisplayID)
        #expect(AppSettings.tickerDisplayID(in: defaults) == 69_734_272)
    }
}
