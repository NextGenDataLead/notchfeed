import Foundation

/// URLProtocol that serves canned responses and redirects; only used by the serialized
/// `URLSessionHTTPClientTests`, so the shared table is guarded by a lock rather than an actor.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private enum Route {
        case body(String)
        case redirect(URL)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var routes: [String: Route] = [:]
    nonisolated(unsafe) private static var count = 0

    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return configuration
    }

    static func reset() { lock.withLock { routes = [:]; count = 0 } }
    static func respond(to url: String, body: String) { lock.withLock { routes[url] = .body(body) } }
    static func redirect(from url: String, to target: String) { lock.withLock { routes[url] = .redirect(URL(string: target)!) } }
    static var requestCount: Int { lock.withLock { count } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let route = Self.lock.withLock {
            Self.count += 1
            return Self.routes[url.absoluteString]
        }
        switch route {
        case .body(let body):
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        case .redirect(let target):
            let response = HTTPURLResponse(url: url, statusCode: 301, httpVersion: "HTTP/1.1", headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        case nil:
            client?.urlProtocol(self, didFailWithError: URLError(.cannotFindHost))
        }
    }

    override func stopLoading() {}
}
