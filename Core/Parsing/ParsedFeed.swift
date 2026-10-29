import Foundation

/// A feed as read from XML, before it is stored.
public struct ParsedFeed: Sendable, Equatable {
    public let title: String
    public let siteURL: URL?
    public let iconURL: URL?
    public let items: [ParsedItem]

    public init(title: String, siteURL: URL? = nil, iconURL: URL? = nil, items: [ParsedItem]) {
        self.title = title
        self.siteURL = siteURL
        self.iconURL = iconURL
        self.items = items
    }
}

/// One entry of a parsed feed.
public struct ParsedItem: Sendable, Equatable {
    public let guid: String?
    public let title: String
    public let link: URL?
    public let publishedAt: Date?

    public init(guid: String?, title: String, link: URL?, publishedAt: Date? = nil) {
        self.guid = guid
        self.title = title
        self.link = link
        self.publishedAt = publishedAt
    }
}
