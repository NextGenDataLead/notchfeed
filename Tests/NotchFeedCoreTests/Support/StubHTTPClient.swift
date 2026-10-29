import Foundation
@testable import NotchFeedCore

/// Fake `HTTPClient` that answers from a table, records requests and tracks concurrency.
actor StubHTTPClient: HTTPClient {
    struct Response: Sendable {
        var status: Int = 200
        var headers: [String: String] = [:]
        var body = Data()
    }

    private var responses: [URL: Response]
    private let delay: Duration
    private(set) var requests: [URLRequest] = []
    private(set) var maxInFlight = 0
    private var inFlight = 0

    init(_ responses: [URL: Response] = [:], delay: Duration = .zero) {
        self.responses = responses
        self.delay = delay
    }

    func setResponse(_ response: Response, for url: URL) {
        responses[url] = response
    }

    nonisolated func data(for request: URLRequest, allowsInsecure: Bool) async throws -> (Data, HTTPURLResponse) {
        try TransportPolicy.check(request.url, allowsInsecure: allowsInsecure)
        return try await respond(to: request)
    }

    private func respond(to request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        inFlight += 1
        maxInFlight = max(maxInFlight, inFlight)
        defer { inFlight -= 1 }
        if delay > .zero { try await Task.sleep(for: delay) }

        guard let url = request.url, let stub = responses[url] else { throw URLError(.cannotFindHost) }
        let response = HTTPURLResponse(url: url, statusCode: stub.status, httpVersion: "HTTP/1.1", headerFields: stub.headers)!
        return (stub.body, response)
    }
}
