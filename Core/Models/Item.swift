import Foundation
import SwiftData

@Model
public final class Item {
    @Attribute(.unique) public var dedupeKey: String
    public var title: String
    public var link: URL?
    public var publishedAt: Date?
    public var firstSeenAt: Date
    /// Used for ordering and retention: the published date, but never later than first seen,
    /// so items with missing or future dates don't stick to the front of the ticker.
    public var sortDate: Date
    /// Last fetch that still listed the item. Keeps undated items that a feed keeps listing from
    /// being purged and then re-inserted as new.
    public var lastSeenAt: Date = Date.distantPast
    public var isRead: Bool
    public var feed: Feed?

    public init(dedupeKey: String, title: String, link: URL?, publishedAt: Date?, firstSeenAt: Date, feed: Feed) {
        self.dedupeKey = dedupeKey
        self.title = title
        self.link = link
        self.publishedAt = publishedAt
        self.firstSeenAt = firstSeenAt
        self.sortDate = Item.sortDate(publishedAt: publishedAt, firstSeenAt: firstSeenAt)
        self.lastSeenAt = firstSeenAt
        self.isRead = false
        self.feed = feed
    }

    static func sortDate(publishedAt: Date?, firstSeenAt: Date) -> Date {
        min(publishedAt ?? firstSeenAt, firstSeenAt)
    }
}
