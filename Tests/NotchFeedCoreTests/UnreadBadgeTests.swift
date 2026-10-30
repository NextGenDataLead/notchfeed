import Testing
@testable import NotchFeedCore

struct UnreadBadgeTests {
    @Test func hasNoBadgeWithoutUnreadItems() {
        #expect(UnreadBadge(unread: 0) == nil)
        #expect(UnreadBadge(unread: -1) == nil)
    }

    @Test func showsCountsUpToTheCap() {
        #expect(UnreadBadge(unread: 1) == .count(1))
        #expect(UnreadBadge(unread: 99) == .count(99))
    }

    @Test func capsLargeCounts() {
        #expect(UnreadBadge(unread: 100) == .overflow(99))
        #expect(UnreadBadge(unread: 296) == .overflow(99))
    }
}
