import Foundation

/// Every network request of the app goes through this, so the transport policy holds everywhere (NFR-7).
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest, allowsInsecure: Bool) async throws -> (Data, HTTPURLResponse)
}

/// Https only, unless the feed allows plain http (see DECISIONS.md). ATS is off for the app,
/// so this check is what keeps http out.
public enum TransportPolicy {
    public static func check(_ url: URL?, allowsInsecure: Bool) throws(FetchError) {
        switch url?.scheme?.lowercased() {
        case "https": return
        case "http": if !allowsInsecure { throw .insecureConnectionNotAllowed }
        default: throw .unsupportedURL
        }
    }
}

public final class URLSessionHTTPClient: HTTPClient {
    public static let defaultMaxResponseBytes = 10 * 1024 * 1024

    private let session: URLSession
    private let maxResponseBytes: Int

    public init(configuration: URLSessionConfiguration = URLSessionHTTPClient.defaultConfiguration(),
                maxResponseBytes: Int = URLSessionHTTPClient.defaultMaxResponseBytes) {
        self.session = URLSession(configuration: configuration)
        self.maxResponseBytes = maxResponseBytes
    }

    /// No URL cache: the fetcher does its own conditional requests and must see real 304s.
    public static func defaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.httpCookieStorage = nil
        return configuration
    }

    public func data(for request: URLRequest, allowsInsecure: Bool) async throws -> (Data, HTTPURLResponse) {
        try TransportPolicy.check(request.url, allowsInsecure: allowsInsecure)
        let (data, response) = try await session.data(for: request, delegate: RedirectPolicy(allowsInsecure: allowsInsecure))
        guard let http = response as? HTTPURLResponse else { throw FetchError.unsupportedURL }
        if (300..<400).contains(http.statusCode), http.statusCode != 304 {
            // The redirect policy refused to follow; tell the caller why.
            let location = http.value(forHTTPHeaderField: "Location").flatMap { URL(string: $0, relativeTo: http.url) }
            try TransportPolicy.check(location, allowsInsecure: allowsInsecure)
        }
        guard data.count <= maxResponseBytes else { throw FetchError.tooLarge }
        return (data, http)
    }
}

/// Stops a redirect from an https feed to plain http.
private final class RedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    private let allowsInsecure: Bool

    init(allowsInsecure: Bool) {
        self.allowsInsecure = allowsInsecure
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        (try? TransportPolicy.check(request.url, allowsInsecure: allowsInsecure)) == nil ? nil : request
    }
}
