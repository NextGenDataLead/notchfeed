import Foundation
import Testing
@testable import NotchFeedCore

struct RelativeAgeTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func age(_ seconds: TimeInterval) -> RelativeAge {
        RelativeAge(of: now.addingTimeInterval(-seconds), now: now)
    }

    @Test func bucketsByMinutesHoursAndDays() {
        #expect(age(0) == .justNow)
        #expect(age(59) == .justNow)
        #expect(age(60) == .minutes(1))
        #expect(age(59 * 60 + 59) == .minutes(59))
        #expect(age(60 * 60) == .hours(1))
        #expect(age(23 * 3600 + 3599) == .hours(23))
        #expect(age(24 * 3600) == .days(1))
        #expect(age(29 * 86_400) == .days(29))
    }

    @Test func futureDatesCountAsJustNow() {
        #expect(age(-3600) == .justNow)
    }
}
