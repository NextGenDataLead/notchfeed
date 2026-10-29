import Foundation
import SwiftData

public enum FeedStoreError: Error, Equatable {
    case feedNotFound
}

/// All writes to feeds and items, off the main actor.
@ModelActor
public actor FeedStore {
    public func addFeed(url: URL, title: String, allowsInsecureConnection: Bool = false, now: Date = .now) throws -> UUID {
        let feed = Feed(url: url, title: title, allowsInsecureConnection: allowsInsecureConnection, createdAt: now)
        modelContext.insert(feed)
        try modelContext.save()
        return feed.id
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
        // A batch delete fails on the Feed <-> Item inverse, so delete item by item.
        let expired = try modelContext.fetch(FetchDescriptor<Item>(predicate: #Predicate { $0.sortDate < cutoff }))
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
