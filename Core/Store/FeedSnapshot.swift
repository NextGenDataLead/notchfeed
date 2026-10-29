import Foundation

/// What a refresh needs to know about a feed, as a value that can leave the store actor.
public struct FeedSnapshot: Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public let siteURL: URL?
    public let etag: String?
    public let lastModified: String?
    public let allowsInsecureConnection: Bool
    public let retryAfter: Date?
    public let faviconFetchedAt: Date?

    init(_ feed: Feed) {
        id = feed.id
        url = feed.url
        siteURL = feed.siteURL
        etag = feed.etag
        lastModified = feed.lastModified
        allowsInsecureConnection = feed.allowsInsecureConnection
        retryAfter = feed.retryAfter
        faviconFetchedAt = feed.faviconFetchedAt
    }
}
