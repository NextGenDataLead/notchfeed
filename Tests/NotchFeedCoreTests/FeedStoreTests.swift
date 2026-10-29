import Foundation
import SwiftData
import Testing
@testable import NotchFeedCore

struct FeedStoreTests {
    private let container: ModelContainer
    private let store: FeedStore
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        store = FeedStore(modelContainer: container)
    }

    private func days(_ count: Double) -> TimeInterval { count * 86_400 }

    private func item(_ guid: String, title: String? = nil, daysOld: Double = 1) -> ParsedItem {
        ParsedItem(
            guid: guid,
            title: title ?? "Item \(guid)",
            link: URL(string: "https://example.com/\(guid)"),
            publishedAt: now.addingTimeInterval(-days(daysOld))
        )
    }

    private func addFeed() async throws -> UUID {
        try await store.addFeed(url: URL(string: "https://example.com/feed.xml")!, title: "Example", now: now)
    }

    private func fetchItems() throws -> [Item] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.dedupeKey)]))
    }

    @Test func ingestInsertsNewItems() async throws {
        let feedID = try await addFeed()
        let inserted = try await store.ingest([item("a"), item("b")], feedID: feedID, now: now, retentionDays: 30)
        #expect(inserted == 2)
        #expect(try fetchItems().count == 2)
    }

    @Test func ingestingTheSameItemsTwiceDoesNotDuplicate() async throws {
        let feedID = try await addFeed()
        _ = try await store.ingest([item("a"), item("b")], feedID: feedID, now: now, retentionDays: 30)
        let inserted = try await store.ingest([item("a"), item("b"), item("c")], feedID: feedID, now: now, retentionDays: 30)
        #expect(inserted == 1)
        #expect(try fetchItems().count == 3)
    }

    @Test func duplicatesWithinOneFetchAreInsertedOnce() async throws {
        let feedID = try await addFeed()
        let inserted = try await store.ingest([item("a"), item("a")], feedID: feedID, now: now, retentionDays: 30)
        #expect(inserted == 1)
    }

    @Test func readStateSurvivesReingest() async throws {
        let feedID = try await addFeed()
        _ = try await store.ingest([item("a")], feedID: feedID, now: now, retentionDays: 30)
        let key = try #require(fetchItems().first?.dedupeKey)
        try await store.markRead(dedupeKey: key)

        _ = try await store.ingest([item("a", title: "Edited title")], feedID: feedID, now: now, retentionDays: 30)

        let stored = try #require(fetchItems().first)
        #expect(stored.isRead)
        #expect(stored.title == "Edited title")
    }

    @Test func ingestSkipsItemsOlderThanRetention() async throws {
        let feedID = try await addFeed()
        let inserted = try await store.ingest([item("old", daysOld: 31), item("new", daysOld: 2)], feedID: feedID, now: now, retentionDays: 30)
        #expect(inserted == 1)
        #expect(try fetchItems().map(\.title) == ["Item new"])
    }

    @Test func purgeRemovesItemsOlderThanCutoff() async throws {
        let feedID = try await addFeed()
        _ = try await store.ingest([item("a", daysOld: 10), item("b", daysOld: 2)], feedID: feedID, now: now, retentionDays: 30)

        let removed = try await store.purge(retentionDays: 5, now: now)

        #expect(removed == 1)
        #expect(try fetchItems().map(\.title) == ["Item b"])
    }

    @Test func undatedItemStillInFeedIsNotPurgedAndDoesNotReturnAsNew() async throws {
        let feedID = try await addFeed()
        let undated = ParsedItem(guid: "u", title: "Undated", link: nil, publishedAt: nil)
        _ = try await store.ingest([undated], feedID: feedID, now: now, retentionDays: 30)
        let key = try #require(fetchItems().first?.dedupeKey)
        try await store.markRead(dedupeKey: key)

        // 40 days later the feed still lists the item.
        let later = now.addingTimeInterval(days(40))
        let inserted = try await store.ingest([undated], feedID: feedID, now: later, retentionDays: 30)
        let removed = try await store.purge(retentionDays: 30, now: later)

        #expect(inserted == 0)
        #expect(removed == 0)
        #expect(try fetchItems().first?.isRead == true)
    }

    @Test func undatedItemIsPurgedOnceTheFeedStopsListingIt() async throws {
        let feedID = try await addFeed()
        let undated = ParsedItem(guid: "u", title: "Undated", link: nil, publishedAt: nil)
        _ = try await store.ingest([undated], feedID: feedID, now: now, retentionDays: 30)

        let removed = try await store.purge(retentionDays: 30, now: now.addingTimeInterval(days(31)))

        #expect(removed == 1)
    }

    @Test func futureDatesSortNoLaterThanFirstSeen() async throws {
        let feedID = try await addFeed()
        let future = ParsedItem(guid: "f", title: "Future", link: nil, publishedAt: now.addingTimeInterval(days(3)))
        _ = try await store.ingest([future], feedID: feedID, now: now, retentionDays: 30)
        let stored = try #require(fetchItems().first)
        #expect(stored.sortDate == now)
    }

    @Test func itemWithoutDateUsesFirstSeen() async throws {
        let feedID = try await addFeed()
        let undated = ParsedItem(guid: "u", title: "Undated", link: nil, publishedAt: nil)
        _ = try await store.ingest([undated], feedID: feedID, now: now, retentionDays: 30)
        let stored = try #require(fetchItems().first)
        #expect(stored.sortDate == now)
        #expect(stored.publishedAt == nil)
    }

    @Test func deletingFeedDeletesItsItems() async throws {
        let feedID = try await addFeed()
        _ = try await store.ingest([item("a"), item("b")], feedID: feedID, now: now, retentionDays: 30)

        try await store.deleteFeed(id: feedID)

        #expect(try fetchItems().isEmpty)
        let feeds = try ModelContext(container).fetch(FetchDescriptor<Feed>())
        #expect(feeds.isEmpty)
    }

    @Test func ingestIntoUnknownFeedThrows() async throws {
        await #expect(throws: FeedStoreError.feedNotFound) {
            try await store.ingest([item("a")], feedID: UUID(), now: now, retentionDays: 30)
        }
    }
}
