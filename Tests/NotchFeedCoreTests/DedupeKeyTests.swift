import Foundation
import Testing
@testable import NotchFeedCore

struct DedupeKeyTests {
    private let feedID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let otherFeedID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    @Test func prefersGUID() {
        let item = ParsedItem(guid: "abc-123", title: "Title", link: URL(string: "https://example.com/a"))
        #expect(DedupeKey.make(feedID: feedID, item: item) == "\(feedID.uuidString)|g:abc-123")
    }

    @Test func fallsBackToLinkWhenGUIDMissingOrBlank() {
        let link = URL(string: "https://example.com/a")
        let missing = ParsedItem(guid: nil, title: "Title", link: link)
        let blank = ParsedItem(guid: "  \n", title: "Title", link: link)
        let expected = "\(feedID.uuidString)|l:https://example.com/a"
        #expect(DedupeKey.make(feedID: feedID, item: missing) == expected)
        #expect(DedupeKey.make(feedID: feedID, item: blank) == expected)
    }

    @Test func fallsBackToStableHashOfTitleAndDate() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let item = ParsedItem(guid: nil, title: "Only a title", link: nil, publishedAt: date)
        let first = DedupeKey.make(feedID: feedID, item: item)
        let second = DedupeKey.make(feedID: feedID, item: item)
        #expect(first == second)
        #expect(first.hasPrefix("\(feedID.uuidString)|h:"))

        let otherDate = ParsedItem(guid: nil, title: "Only a title", link: nil, publishedAt: date.addingTimeInterval(60))
        #expect(DedupeKey.make(feedID: feedID, item: otherDate) != first)
    }

    @Test func sameGUIDInDifferentFeedsGivesDifferentKeys() {
        let item = ParsedItem(guid: "shared", title: "Title", link: nil)
        #expect(DedupeKey.make(feedID: feedID, item: item) != DedupeKey.make(feedID: otherFeedID, item: item))
    }
}
