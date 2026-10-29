import Foundation
import Testing
@testable import NotchFeedCore

/// Covers the transport policy of the real URLSession client, with a URLProtocol stub instead of the network.
@Suite(.serialized)
struct URLSessionHTTPClientTests {
    private let client = URLSessionHTTPClient(configuration: StubURLProtocol.configuration())

    @Test func refusesHTTPBeforeConnecting() async {
        StubURLProtocol.reset()
        await #expect(throws: FetchError.insecureConnectionNotAllowed) {
            try await client.data(for: URLRequest(url: URL(string: "http://example.com/feed")!), allowsInsecure: false)
        }
        #expect(StubURLProtocol.requestCount == 0)
    }

    @Test func refusesOtherSchemes() async {
        await #expect(throws: FetchError.unsupportedURL) {
            try await client.data(for: URLRequest(url: URL(string: "file:///etc/hosts")!), allowsInsecure: true)
        }
    }

    @Test func blocksRedirectToHTTPUnlessAllowed() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.redirect(from: "https://secure.example.com/feed", to: "http://plain.example.com/feed")
        StubURLProtocol.respond(to: "http://plain.example.com/feed", body: "plain")

        await #expect(throws: FetchError.insecureConnectionNotAllowed) {
            try await client.data(for: URLRequest(url: URL(string: "https://secure.example.com/feed")!), allowsInsecure: false)
        }

        let (data, response) = try await client.data(for: URLRequest(url: URL(string: "https://secure.example.com/feed")!), allowsInsecure: true)
        #expect(String(decoding: data, as: UTF8.self) == "plain")
        #expect(response.url == URL(string: "http://plain.example.com/feed"))
    }

    @Test func followsHTTPSRedirects() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.redirect(from: "https://old.example.com/feed", to: "https://new.example.com/feed")
        StubURLProtocol.respond(to: "https://new.example.com/feed", body: "moved")

        let (data, _) = try await client.data(for: URLRequest(url: URL(string: "https://old.example.com/feed")!), allowsInsecure: false)
        #expect(String(decoding: data, as: UTF8.self) == "moved")
    }

    @Test func boundsTheWholeFetchNotJustIdleTime() {
        let configuration = URLSessionHTTPClient.defaultConfiguration()
        #expect(configuration.timeoutIntervalForResource <= 120)
        #expect(configuration.urlCache == nil)
    }

    @Test func acceptsResponsesUpToTheLimit() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.respond(to: "https://ok.example.com/feed", body: String(repeating: "x", count: 1_024))
        let small = URLSessionHTTPClient(configuration: StubURLProtocol.configuration(), maxResponseBytes: 1_024)

        let (data, _) = try await small.data(for: URLRequest(url: URL(string: "https://ok.example.com/feed")!), allowsInsecure: false)
        #expect(data.count == 1_024)
    }

    @Test func rejectsOversizedResponses() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.respond(to: "https://big.example.com/feed", body: String(repeating: "x", count: 2_048))
        let small = URLSessionHTTPClient(configuration: StubURLProtocol.configuration(), maxResponseBytes: 1_024)

        await #expect(throws: FetchError.tooLarge) {
            try await small.data(for: URLRequest(url: URL(string: "https://big.example.com/feed")!), allowsInsecure: false)
        }
    }
}
