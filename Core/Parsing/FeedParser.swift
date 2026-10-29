import Foundation

public enum FeedParserError: Error, Equatable, Sendable {
    /// The document parsed but isn't RSS or Atom (for example an HTML page).
    case notAFeed
    /// The data isn't usable XML, even after repair.
    case malformed
}

/// FR-8.1: entry point for RSS 2.0, RSS 1.0 and Atom. Broken XML gets one repair attempt;
/// whichever attempt yields more items wins, so a truncated feed still gives its complete items.
public enum FeedParser {
    public static func parse(_ data: Data, baseURL: URL?) throws(FeedParserError) -> ParsedFeed {
        let first = Attempt(data: data, baseURL: baseURL)
        if !first.failed, let feed = first.feed { return finish(feed, baseURL: baseURL) }

        let repaired = Attempt(data: XMLSanitizer.sanitize(data), baseURL: baseURL)
        let best = [first, repaired]
            .compactMap(\.feed)
            .max { $0.items.count < $1.items.count }
        if let best { return finish(best, baseURL: baseURL) }

        if first.hasUnknownRoot || repaired.hasUnknownRoot { throw .notAFeed }
        throw .malformed
    }

    private static func finish(_ feed: ParsedFeed, baseURL: URL?) -> ParsedFeed {
        guard feed.title.isEmpty else { return feed }
        let title = feed.siteURL?.host() ?? baseURL?.host() ?? ""
        return ParsedFeed(title: title, siteURL: feed.siteURL, iconURL: feed.iconURL, items: feed.items)
    }

    private struct Attempt {
        let feed: ParsedFeed?
        let failed: Bool
        let hasUnknownRoot: Bool

        init(data: Data, baseURL: URL?) {
            let tree = XMLTreeBuilder.build(data)
            let dates = DateParser()
            failed = tree.failed
            switch tree.root?.name {
            case "rss", "RDF":
                feed = tree.root.map { RSSParser.parse(root: $0, baseURL: baseURL, dates: dates) }
                hasUnknownRoot = false
            case "feed":
                feed = tree.root.map { AtomParser.parse(root: $0, baseURL: baseURL, dates: dates) }
                hasUnknownRoot = false
            case nil:
                feed = nil
                hasUnknownRoot = false
            default:
                feed = nil
                hasUnknownRoot = true
            }
        }
    }
}
