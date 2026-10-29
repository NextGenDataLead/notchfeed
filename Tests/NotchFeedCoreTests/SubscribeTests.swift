import Foundation
import SwiftData
import Testing
@testable import NotchFeedCore

/// FR-4.1 (feed URL): validation, https first, the per-feed http opt-in and duplicates.
struct SubscribeTests {
    private let container: ModelContainer
    private let store: FeedStore
    private let now = Date(timeIntervalSince1970: 1_793_300_000)
    private let feedBody: Data

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        store = FeedStore(modelContainer: container)
        feedBody = try Fixtures.data("real-hnrss-rss2.xml")
    }

    private func coordinator(_ client: StubHTTPClient) -> RefreshCoordinator {
        RefreshCoordinator(store: store, fetcher: FeedFetcher(client: client), favicons: FaviconFetcher(client: client), retentionDays: { 30 })
    }

    private func feeds() throws -> [Feed] {
        try ModelContext(container).fetch(FetchDescriptor<Feed>())
    }

    @Test func addsFeedWithTitleAndItems() async throws {
        let url = URL(string: "https://hnrss.org/frontpage")!
        let client = StubHTTPClient([url: .init(body: feedBody)])

        _ = try await coordinator(client).subscribe(to: "https://hnrss.org/frontpage", allowsInsecure: false, now: now)

        let feed = try #require(try feeds().first)
        #expect(feed.url == url)
        #expect(feed.title == "Hacker News: Front Page")
        #expect(feed.items.count == 3)
        #expect(feed.allowsInsecureConnection == false)
        #expect(feed.lastFetchedAt == now)
    }

    @Test(arguments: ["hnrss.org/frontpage", "  https://hnrss.org/frontpage  ", "feed://hnrss.org/frontpage", "feed:https://hnrss.org/frontpage"])
    func normalisesInput(_ input: String) async throws {
        let client = StubHTTPClient([URL(string: "https://hnrss.org/frontpage")!: .init(body: feedBody)])
        _ = try await coordinator(client).subscribe(to: input, allowsInsecure: false, now: now)
        #expect(try feeds().first?.url == URL(string: "https://hnrss.org/frontpage"))
    }

    @Test(arguments: ["", "not a url", "ftp://example.com/feed", "https://", "javascript:alert(1)"])
    func rejectsInvalidInput(_ input: String) async throws {
        await #expect(throws: SubscribeError.invalidURL) {
            try await coordinator(StubHTTPClient()).subscribe(to: input, allowsInsecure: false, now: now)
        }
    }

    @Test func upgradesHTTPToHTTPSWhenAvailable() async throws {
        let client = StubHTTPClient([URL(string: "https://example.com/rss")!: .init(body: feedBody)])

        _ = try await coordinator(client).subscribe(to: "http://example.com/rss", allowsInsecure: false, now: now)

        let feed = try #require(try feeds().first)
        #expect(feed.url == URL(string: "https://example.com/rss"))
        #expect(feed.allowsInsecureConnection == false)
    }

    @Test func refusesHTTPWhenHTTPSFailsAndNotAllowed() async throws {
        let client = StubHTTPClient([URL(string: "http://example.com/rss")!: .init(body: feedBody)])

        await #expect(throws: SubscribeError.httpsUnavailable) {
            try await coordinator(client).subscribe(to: "http://example.com/rss", allowsInsecure: false, now: now)
        }
        #expect(try feeds().isEmpty)
        #expect(await client.requests.allSatisfy { $0.url?.scheme == "https" })
    }

    @Test func usesHTTPWhenAllowedAndHTTPSFails() async throws {
        let client = StubHTTPClient([URL(string: "http://example.com/rss")!: .init(body: feedBody)])

        _ = try await coordinator(client).subscribe(to: "http://example.com/rss", allowsInsecure: true, now: now)

        let feed = try #require(try feeds().first)
        #expect(feed.url == URL(string: "http://example.com/rss"))
        #expect(feed.allowsInsecureConnection)
    }

    @Test func refusesDuplicates() async throws {
        let client = StubHTTPClient([URL(string: "https://example.com/rss")!: .init(body: feedBody)])
        let coordinator = coordinator(client)
        _ = try await coordinator.subscribe(to: "https://example.com/rss", allowsInsecure: false, now: now)

        await #expect(throws: SubscribeError.alreadySubscribed) {
            try await coordinator.subscribe(to: "example.com/rss", allowsInsecure: false, now: now)
        }
        await #expect(throws: SubscribeError.alreadySubscribed) {
            try await coordinator.subscribe(to: "http://example.com/rss", allowsInsecure: false, now: now)
        }
        #expect(try feeds().count == 1)
    }

    @Test func reportsPagesThatAreNotFeeds() async throws {
        let client = StubHTTPClient([URL(string: "https://example.com/")!: .init(body: try Fixtures.data("not-a-feed.html"))])

        await #expect(throws: SubscribeError.fetch(.parse(.notAFeed))) {
            try await coordinator(client).subscribe(to: "https://example.com/", allowsInsecure: false, now: now)
        }
        #expect(try feeds().isEmpty)
    }
}
