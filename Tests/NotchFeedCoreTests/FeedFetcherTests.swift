import Foundation
import Testing
@testable import NotchFeedCore

struct FeedFetcherTests {
    private let feedURL = URL(string: "https://example.com/feed.xml")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func fetcher(_ response: StubHTTPClient.Response) -> (FeedFetcher, StubHTTPClient) {
        let client = StubHTTPClient([feedURL: response])
        return (FeedFetcher(client: client), client)
    }

    private func request(etag: String? = nil, lastModified: String? = nil, url: URL? = nil, allowsInsecure: Bool = false) -> FetchRequest {
        FetchRequest(url: url ?? feedURL, etag: etag, lastModified: lastModified, allowsInsecureConnection: allowsInsecure)
    }

    @Test func sendsConditionalHeaders() async throws {
        let (fetcher, client) = fetcher(.init(status: 304))
        _ = try await fetcher.fetch(request(etag: "\"v1\"", lastModified: "Tue, 27 Oct 2026 09:30:00 GMT"), now: now)

        let sent = try #require(await client.requests.first)
        #expect(sent.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"")
        #expect(sent.value(forHTTPHeaderField: "If-Modified-Since") == "Tue, 27 Oct 2026 09:30:00 GMT")
        #expect(sent.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("NotchFeed/") == true)
    }

    @Test func omitsConditionalHeadersWithoutValidators() async throws {
        let (fetcher, client) = fetcher(.init(body: try Fixtures.data("real-hnrss-rss2.xml")))
        _ = try await fetcher.fetch(request(), now: now)
        let sent = try #require(await client.requests.first)
        #expect(sent.value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(sent.value(forHTTPHeaderField: "If-Modified-Since") == nil)
    }

    @Test func returnsParsedFeedAndValidatorsOn200() async throws {
        let headers = ["ETag": "\"v2\"", "Last-Modified": "Wed, 28 Oct 2026 10:00:00 GMT"]
        let (fetcher, _) = fetcher(.init(headers: headers, body: try Fixtures.data("real-hnrss-rss2.xml")))

        let result = try await fetcher.fetch(request(), now: now)

        guard case let .updated(feed, etag, lastModified) = result else {
            Issue.record("expected .updated, got \(result)")
            return
        }
        #expect(feed.items.count == 3)
        #expect(etag == "\"v2\"")
        #expect(lastModified == "Wed, 28 Oct 2026 10:00:00 GMT")
    }

    @Test func handles304AsNotModified() async throws {
        let (fetcher, _) = fetcher(.init(status: 304))
        #expect(try await fetcher.fetch(request(etag: "\"v1\""), now: now) == .notModified)
    }

    @Test func readsRetryAfterSecondsOn429() async throws {
        let (fetcher, _) = fetcher(.init(status: 429, headers: ["Retry-After": "120"]))
        await #expect(throws: FetchError.rateLimited(retryAfter: now.addingTimeInterval(120))) {
            try await fetcher.fetch(request(), now: now)
        }
    }

    @Test func readsRetryAfterHTTPDateOn429() async throws {
        let (fetcher, _) = fetcher(.init(status: 429, headers: ["Retry-After": "Fri, 15 Jan 2027 08:00:00 GMT"]))
        let expected = try #require(DateParser().date(from: "2027-01-15T08:00:00Z"))
        await #expect(throws: FetchError.rateLimited(retryAfter: expected)) {
            try await fetcher.fetch(request(), now: now)
        }
    }

    @Test func defaultsRetryAfterWhenHeaderMissingAndCapsLongValues() async throws {
        let (missing, _) = fetcher(.init(status: 429))
        await #expect(throws: FetchError.rateLimited(retryAfter: now.addingTimeInterval(FeedFetcher.defaultRetryAfter))) {
            try await missing.fetch(request(), now: now)
        }
        let (huge, _) = fetcher(.init(status: 503, headers: ["Retry-After": "9999999"]))
        await #expect(throws: FetchError.rateLimited(retryAfter: now.addingTimeInterval(FeedFetcher.maxRetryAfter))) {
            try await huge.fetch(request(), now: now)
        }
    }

    @Test func reportsServerErrors() async throws {
        let (fetcher, _) = fetcher(.init(status: 500))
        await #expect(throws: FetchError.httpStatus(500)) {
            try await fetcher.fetch(request(), now: now)
        }
    }

    @Test func reportsParseErrors() async throws {
        let (fetcher, _) = fetcher(.init(body: try Fixtures.data("not-a-feed.html")))
        await #expect(throws: FetchError.parse(.notAFeed)) {
            try await fetcher.fetch(request(), now: now)
        }
    }

    @Test func refusesPlainHTTPUnlessAllowed() async throws {
        let httpURL = URL(string: "http://example.com/feed.xml")!
        let client = StubHTTPClient([httpURL: .init(body: try Fixtures.data("real-hnrss-rss2.xml"))])
        let fetcher = FeedFetcher(client: client)

        await #expect(throws: FetchError.insecureConnectionNotAllowed) {
            try await fetcher.fetch(request(url: httpURL), now: now)
        }
        #expect(await client.requests.isEmpty)

        let result = try await fetcher.fetch(request(url: httpURL, allowsInsecure: true), now: now)
        guard case .updated = result else {
            Issue.record("expected .updated")
            return
        }
    }

    @Test(arguments: [
        FetchError.insecureConnectionNotAllowed, .unsupportedURL, .rateLimited(retryAfter: .distantPast),
        .httpStatus(404), .parse(.notAFeed), .parse(.malformed), .transport(code: -1009), .tooLarge,
    ])
    func errorStorageCodeRoundTrips(_ error: FetchError) {
        let decoded = FetchError(storageCode: error.storageCode)
        if case .rateLimited = error {
            #expect(decoded == .rateLimited(retryAfter: .distantPast))
        } else {
            #expect(decoded == error)
        }
    }
}
