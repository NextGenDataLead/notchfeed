import Foundation
import SwiftData
import Testing
@testable import NotchFeedCore

struct RefreshCoordinatorTests {
    private let container: ModelContainer
    private let store: FeedStore
    private let now = Date(timeIntervalSince1970: 1_793_300_000) // 2026-10-29, close to the fixture dates

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        store = FeedStore(modelContainer: container)
    }

    private func coordinator(_ client: StubHTTPClient) -> RefreshCoordinator {
        RefreshCoordinator(
            store: store,
            fetcher: FeedFetcher(client: client),
            favicons: FaviconFetcher(client: client),
            retentionDays: { 30 }
        )
    }

    private func feeds() throws -> [Feed] {
        try ModelContext(container).fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    @Test func neverRunsMoreThanSixFetchesAtOnce() async throws {
        let body = try Fixtures.data("real-hnrss-rss2.xml")
        var responses: [URL: StubHTTPClient.Response] = [:]
        for index in 0..<20 {
            let url = URL(string: "https://feed\(index).example.com/rss")!
            responses[url] = .init(body: body)
            _ = try await store.addFeed(url: url, title: "Feed \(index)", now: now)
        }
        let client = StubHTTPClient(responses, delay: .milliseconds(20))

        await coordinator(client).refreshAll(now: now)

        let max = await client.maxInFlight
        #expect(max <= 6)
        #expect(max > 1)
        // 20 feeds plus a favicon attempt each (stub answers favicons with "host not found").
        #expect(await client.requests.filter { $0.url?.path() == "/rss" }.count == 20)
    }

    @Test func storesItemsValidatorsAndFetchTime() async throws {
        let url = URL(string: "https://example.com/rss")!
        _ = try await store.addFeed(url: url, title: "Example", now: now)
        let client = StubHTTPClient([url: .init(headers: ["ETag": "\"abc\""], body: try Fixtures.data("real-hnrss-rss2.xml"))])

        await coordinator(client).refreshAll(now: now)

        let feed = try #require(try feeds().first)
        #expect(feed.items.count == 3)
        #expect(feed.etag == "\"abc\"")
        #expect(feed.lastFetchedAt == now)
        #expect(feed.lastError == nil)
        #expect(feed.siteURL == URL(string: "https://news.ycombinator.com/"))
    }

    @Test func recordsErrorsAndRetryAfter() async throws {
        let url = URL(string: "https://example.com/rss")!
        _ = try await store.addFeed(url: url, title: "Example", now: now)
        let client = StubHTTPClient([url: .init(status: 429, headers: ["Retry-After": "600"])])
        let coordinator = coordinator(client)

        await coordinator.refreshAll(now: now)

        let feed = try #require(try feeds().first)
        #expect(feed.lastError == FetchError.rateLimited(retryAfter: .distantPast).storageCode)
        #expect(feed.retryAfter == now.addingTimeInterval(600))

        // Inside the Retry-After window the feed is skipped.
        await coordinator.refreshAll(now: now.addingTimeInterval(60))
        #expect(await client.requests.count == 1)
    }

    @Test func storesFeedIconAsFavicon() async throws {
        let url = URL(string: "https://example.com/rss")!
        _ = try await store.addFeed(url: url, title: "Example", now: now)
        let client = StubHTTPClient([
            url: .init(body: try Fixtures.data("rss2-no-guid.xml")),
            URL(string: "https://example.com/icon.png")!: .init(headers: ["Content-Type": "image/png"], body: TestImages.png),
        ])

        await coordinator(client).refreshAll(now: now)

        let feed = try #require(try feeds().first)
        #expect(feed.faviconData == TestImages.png)
        #expect(feed.faviconFetchedAt == now)
    }
}
