import Foundation
import SwiftData

public enum FeedStoreError: Error, Equatable {
    case feedNotFound
    case duplicateURL
}

/// All writes to feeds and items, off the main actor.
@ModelActor
public actor FeedStore {
    public func addFeed(url: URL, title: String, allowsInsecureConnection: Bool = false, now: Date = .now) throws -> UUID {
        guard try !hasFeed(withAnyOf: [url]) else { throw FeedStoreError.duplicateURL }
        let feed = Feed(url: url, title: title, allowsInsecureConnection: allowsInsecureConnection, createdAt: now)
        modelContext.insert(feed)
        try modelContext.save()
        return feed.id
    }

    /// Feed URLs compare by host (any case), path and query, without the scheme or a trailing slash,
    /// so `http://x/rss` and `https://X/rss/` are one feed but `/Feed` and `/feed` are two.
    public func hasFeed(withAnyOf urls: [URL]) throws -> Bool {
        let wanted = Set(urls.map(Self.comparable))
        return try modelContext.fetch(FetchDescriptor<Feed>()).contains { wanted.contains(Self.comparable($0.url)) }
    }

    public func snapshot(feedID: UUID) throws -> FeedSnapshot {
        FeedSnapshot(try feed(id: feedID))
    }

    private static func comparable(_ url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url.absoluteString }
        var path = components.percentEncodedPath
        if path.hasSuffix("/") { path.removeLast() }
        let port = components.port.map { ":\($0)" } ?? ""
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return (components.host?.lowercased() ?? "") + port + path + query
    }

    public func deleteFeed(id: UUID) throws {
        modelContext.delete(try feed(id: id))
        try modelContext.save()
    }

    /// Inserts new items and refreshes title and link of known ones, keeping their read state.
    /// Items already older than the retention window are skipped, so purged items don't return.
    /// Returns the number of inserted items.
    @discardableResult
    public func ingest(_ parsedItems: [ParsedItem], feedID: UUID, now: Date = .now, retentionDays: Int) throws -> Int {
        let feed = try feed(id: feedID)
        let cutoff = Self.cutoff(retentionDays: retentionDays, now: now)

        let candidates = parsedItems
            .map { (key: DedupeKey.make(feedID: feedID, item: $0), item: $0) }
            .filter { Item.sortDate(publishedAt: $0.item.publishedAt, firstSeenAt: now) >= cutoff }
        let keys = candidates.map(\.key)
        let existing = try modelContext.fetch(FetchDescriptor<Item>(predicate: #Predicate { keys.contains($0.dedupeKey) }))
        var known = Dictionary(existing.map { ($0.dedupeKey, $0) }, uniquingKeysWith: { first, _ in first })

        var inserted = 0
        for candidate in candidates {
            if let item = known[candidate.key] {
                if item.title != candidate.item.title { item.title = candidate.item.title }
                if item.link != candidate.item.link { item.link = candidate.item.link }
                item.lastSeenAt = now
                continue
            }
            let item = Item(
                dedupeKey: candidate.key,
                title: candidate.item.title,
                link: candidate.item.link,
                publishedAt: candidate.item.publishedAt,
                firstSeenAt: now,
                feed: feed
            )
            modelContext.insert(item)
            known[candidate.key] = item
            inserted += 1
        }
        try modelContext.save()
        return inserted
    }

    // MARK: Fetch bookkeeping

    public func refreshTargets() throws -> [FeedSnapshot] {
        try modelContext.fetch(FetchDescriptor<Feed>(sortBy: [SortDescriptor(\.createdAt)])).map(FeedSnapshot.init)
    }

    /// Stores validators and new items after a 200. Returns the number of inserted items.
    @discardableResult
    public func recordSuccess(feedID: UUID, parsed: ParsedFeed, etag: String?, lastModified: String?,
                              now: Date, retentionDays: Int) throws -> Int {
        let feed = try feed(id: feedID)
        feed.etag = etag
        feed.lastModified = lastModified
        feed.lastFetchedAt = now
        feed.lastError = nil
        feed.retryAfter = nil
        if let siteURL = parsed.siteURL { feed.siteURL = siteURL }
        if feed.title.isEmpty { feed.title = parsed.title }
        return try ingest(parsed.items, feedID: feedID, now: now, retentionDays: retentionDays)
    }

    public func recordNotModified(feedID: UUID, now: Date) throws {
        let feed = try feed(id: feedID)
        feed.lastFetchedAt = now
        feed.lastError = nil
        feed.retryAfter = nil
        try modelContext.save()
    }

    public func recordFailure(feedID: UUID, errorCode: String, retryAfter: Date?, now: Date) throws {
        let feed = try feed(id: feedID)
        feed.lastFetchedAt = now
        feed.lastError = errorCode
        feed.retryAfter = retryAfter
        try modelContext.save()
    }

    /// Keeps an existing icon when a refresh finds none, but records the attempt so it isn't retried each cycle.
    public func setFavicon(feedID: UUID, data: Data?, now: Date) throws {
        let feed = try feed(id: feedID)
        if let data { feed.faviconData = data }
        feed.faviconFetchedAt = now
        try modelContext.save()
    }

    // MARK: Read state

    public func markRead(dedupeKey: String) throws {
        let descriptor = FetchDescriptor<Item>(predicate: #Predicate { $0.dedupeKey == dedupeKey })
        guard let item = try modelContext.fetch(descriptor).first, !item.isRead else { return }
        item.isRead = true
        try modelContext.save()
    }

    /// FR-4.6: removes items older than the retention window. Returns the number removed.
    @discardableResult
    public func purge(retentionDays: Int, now: Date = .now) throws -> Int {
        let cutoff = Self.cutoff(retentionDays: retentionDays, now: now)
        // Dated items past the window are never re-inserted (ingest skips them). Undated ones would be,
        // so they stay while the feed still lists them. A batch delete fails on the Feed <-> Item
        // inverse, so delete item by item.
        let expired = try modelContext.fetch(FetchDescriptor<Item>(predicate: #Predicate {
            $0.sortDate < cutoff && ($0.publishedAt != nil || $0.lastSeenAt < cutoff)
        }))
        guard !expired.isEmpty else { return 0 }
        expired.forEach(modelContext.delete)
        try modelContext.save()
        return expired.count
    }

    private func feed(id: UUID) throws -> Feed {
        let descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.id == id })
        guard let feed = try modelContext.fetch(descriptor).first else { throw FeedStoreError.feedNotFound }
        return feed
    }

    private static func cutoff(retentionDays: Int, now: Date) -> Date {
        now.addingTimeInterval(-Double(retentionDays) * 86_400)
    }
}
