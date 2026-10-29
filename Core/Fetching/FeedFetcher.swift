import Foundation

public struct FetchRequest: Sendable, Equatable {
    public let url: URL
    public let etag: String?
    public let lastModified: String?
    public let allowsInsecureConnection: Bool

    public init(url: URL, etag: String? = nil, lastModified: String? = nil, allowsInsecureConnection: Bool = false) {
        self.url = url
        self.etag = etag
        self.lastModified = lastModified
        self.allowsInsecureConnection = allowsInsecureConnection
    }
}

public enum FetchResult: Sendable, Equatable {
    case updated(ParsedFeed, etag: String?, lastModified: String?)
    case notModified
}

/// FR-8.2: one conditional GET of a feed, parsed off the main actor.
public struct FeedFetcher: Sendable {
    /// Used when a 429 has no usable Retry-After header.
    public static let defaultRetryAfter: TimeInterval = 60 * 60
    /// Retry-After values beyond this are capped, so a feed can't silence itself for weeks.
    public static let maxRetryAfter: TimeInterval = 24 * 60 * 60

    static let userAgent = "NotchFeed/0.1 (macOS; +https://github.com/NextGenDataLead/notchfeed)"
    private static let accept = "application/rss+xml, application/atom+xml, application/rdf+xml;q=0.9, application/xml;q=0.9, text/xml;q=0.9, */*;q=0.8"

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func fetch(_ request: FetchRequest, now: Date = .now) async throws(FetchError) -> FetchResult {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        urlRequest.setValue(Self.accept, forHTTPHeaderField: "Accept")
        if let etag = request.etag { urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified = request.lastModified { urlRequest.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await client.data(for: urlRequest, allowsInsecure: request.allowsInsecureConnection)
        } catch let error as FetchError {
            throw error
        } catch let error as URLError {
            throw .transport(code: error.errorCode)
        } catch {
            throw .transport(code: URLError.Code.unknown.rawValue)
        }

        switch response.statusCode {
        case 304:
            return .notModified
        case 200..<300:
            do {
                let feed = try FeedParser.parse(data, baseURL: response.url ?? request.url)
                return .updated(
                    feed,
                    etag: response.value(forHTTPHeaderField: "ETag"),
                    lastModified: response.value(forHTTPHeaderField: "Last-Modified")
                )
            } catch {
                throw .parse(error)
            }
        case 429:
            throw .rateLimited(retryAfter: retryAfter(response, now: now) ?? now.addingTimeInterval(Self.defaultRetryAfter))
        case 503 where response.value(forHTTPHeaderField: "Retry-After") != nil:
            throw .rateLimited(retryAfter: retryAfter(response, now: now) ?? now.addingTimeInterval(Self.defaultRetryAfter))
        default:
            throw .httpStatus(response.statusCode)
        }
    }

    /// Retry-After as seconds or as an HTTP date, capped at `maxRetryAfter`.
    private func retryAfter(_ response: HTTPURLResponse, now: Date) -> Date? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces) else { return nil }
        let date = TimeInterval(value).map { now.addingTimeInterval($0) } ?? DateParser().date(from: value)
        return date.map { min(max($0, now), now.addingTimeInterval(Self.maxRetryAfter)) }
    }
}
