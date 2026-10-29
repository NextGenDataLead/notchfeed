import Foundation

public enum FetchError: Error, Hashable, Sendable {
    /// Plain http (directly or through a redirect) for a feed that doesn't allow it.
    case insecureConnectionNotAllowed
    /// Not an http or https URL.
    case unsupportedURL
    /// 429, or 503 with Retry-After: don't fetch again before the given time.
    case rateLimited(retryAfter: Date)
    case httpStatus(Int)
    case parse(FeedParserError)
    /// A `URLError` code, such as -1009 for "offline".
    case transport(code: Int)
    case tooLarge
}

extension FetchError {
    /// Stable text form stored in `Feed.lastError`; the UI turns it back into a message.
    /// The Retry-After time is stored separately, on `Feed.retryAfter`.
    public var storageCode: String {
        switch self {
        case .insecureConnectionNotAllowed: "insecure"
        case .unsupportedURL: "unsupportedURL"
        case .rateLimited: "rateLimited"
        case .httpStatus(let status): "http:\(status)"
        case .parse(.notAFeed): "parse:notAFeed"
        case .parse(.malformed): "parse:malformed"
        case .transport(let code): "transport:\(code)"
        case .tooLarge: "tooLarge"
        }
    }

    public init?(storageCode: String) {
        let parts = storageCode.split(separator: ":", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("insecure", nil): self = .insecureConnectionNotAllowed
        case ("unsupportedURL", nil): self = .unsupportedURL
        case ("rateLimited", nil): self = .rateLimited(retryAfter: .distantPast)
        case ("http", let status?): guard let code = Int(status) else { return nil }; self = .httpStatus(code)
        case ("parse", "notAFeed"): self = .parse(.notAFeed)
        case ("parse", "malformed"): self = .parse(.malformed)
        case ("transport", let code?): guard let value = Int(code) else { return nil }; self = .transport(code: value)
        case ("tooLarge", nil): self = .tooLarge
        default: return nil
        }
    }
}
