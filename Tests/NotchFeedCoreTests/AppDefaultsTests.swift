import Testing
@testable import NotchFeedCore

struct AppDefaultsTests {
    @Test func defaultsMatchPRD() {
        #expect(AppDefaults.retentionDays == 30)
        #expect(AppDefaults.refreshInterval == .seconds(900))
        #expect(AppDefaults.maxParallelFetches == 6)
        #expect(AppDefaults.tickerPosition == .top)
    }
}
