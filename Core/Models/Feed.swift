import Foundation
import SwiftData

@Model
public final class Feed {
    @Attribute(.unique) public var id: UUID
    public var url: URL
    public var title: String
    public var siteURL: URL?
    public var faviconData: Data?
    public var faviconFetchedAt: Date?
    /// Plain http is refused unless the user allowed it for this feed (see DECISIONS.md).
    public var allowsInsecureConnection: Bool
    public var etag: String?
    public var lastModified: String?
    public var lastFetchedAt: Date?
    public var lastError: String?
    public var retryAfter: Date?
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Item.feed)
    public var items: [Item] = []

    public init(url: URL, title: String, allowsInsecureConnection: Bool = false, createdAt: Date) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.allowsInsecureConnection = allowsInsecureConnection
        self.createdAt = createdAt
    }
}
