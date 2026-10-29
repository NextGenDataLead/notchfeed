import Foundation
import NotchFeedCore

/// User-facing messages for fetch and subscribe errors.
enum FeedErrorText {
    static func message(for error: FetchError, retryAfter: Date? = nil) -> String {
        switch error {
        case .insecureConnectionNotAllowed:
            String(localized: "The feed moved to an insecure (http) address, which isn't allowed for this feed.")
        case .unsupportedURL:
            String(localized: "This isn't a web address NotchFeed can fetch.")
        case .rateLimited:
            if let retryAfter, retryAfter > .now {
                String(localized: "The site asked NotchFeed to wait. Next try after \(retryAfter.formatted(date: .omitted, time: .shortened)).")
            } else {
                String(localized: "The site asked NotchFeed to slow down.")
            }
        case .httpStatus(404), .httpStatus(410):
            String(localized: "The server says this feed doesn't exist.")
        case .httpStatus(let status):
            String(localized: "The server returned an error (HTTP \(status)).")
        case .parse(.notAFeed):
            String(localized: "This address is a web page, not an RSS or Atom feed. Use the address of the feed itself.")
        case .parse(.malformed):
            String(localized: "The feed couldn't be read.")
        case .transport(let code):
            URLError(URLError.Code(rawValue: code)).localizedDescription
        case .tooLarge:
            String(localized: "The feed is larger than 10 MB.")
        }
    }

    static func message(for error: SubscribeError) -> String {
        switch error {
        case .invalidURL:
            String(localized: "Enter a feed address, such as https://example.com/feed.xml.")
        case .alreadySubscribed:
            String(localized: "You already follow this feed.")
        case .httpsUnavailable:
            String(localized: "This feed doesn't work over a secure (https) connection.")
        case .fetch(let fetchError):
            message(for: fetchError)
        }
    }
}
