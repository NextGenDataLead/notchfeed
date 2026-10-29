import Foundation
import os

/// Fetches all feeds on a fixed interval (V0.1: 15 minutes, all at once), with at most
/// `maxParallelFetches` requests in flight (FR-8.5). Feeds inside a Retry-After window are skipped.
public actor RefreshCoordinator {
    private static let purgeInterval: TimeInterval = 24 * 60 * 60
    private static let logger = Logger(subsystem: "com.nextgendatalead.NotchFeed", category: "refresh")

    let store: FeedStore
    let fetcher: FeedFetcher
    private let favicons: FaviconFetcher
    private let maxParallelFetches: Int
    private let retentionDays: @Sendable () -> Int

    private var isRefreshing = false
    private var lastPurge: Date?
    private var loop: Task<Void, Never>?

    public init(store: FeedStore, fetcher: FeedFetcher, favicons: FaviconFetcher,
                maxParallelFetches: Int = AppDefaults.maxParallelFetches,
                retentionDays: @escaping @Sendable () -> Int) {
        self.store = store
        self.fetcher = fetcher
        self.favicons = favicons
        self.maxParallelFetches = maxParallelFetches
        self.retentionDays = retentionDays
    }

    /// Refreshes now and then every `interval`, purging expired items once a day.
    public func start(interval: Duration = AppDefaults.refreshInterval) {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.purgeIfDue(now: .now)
                await self?.refreshAll(now: .now)
                try? await Task.sleep(for: interval)
            }
        }
    }

    public func stop() {
        loop?.cancel()
        loop = nil
    }

    /// "Refresh now" and the timer both land here; a refresh already in progress is not doubled.
    public func refreshAll(now: Date = .now) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let targets: [FeedSnapshot]
        do {
            targets = try await store.refreshTargets().filter { ($0.retryAfter ?? .distantPast) <= now }
        } catch {
            Self.logger.error("Loading feeds failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        await withTaskGroup(of: Void.self) { group in
            var pending = targets.makeIterator()
            for _ in 0..<maxParallelFetches {
                guard let target = pending.next() else { break }
                group.addTask { await self.refresh(target, now: now) }
            }
            while await group.next() != nil {
                if let target = pending.next() {
                    group.addTask { await self.refresh(target, now: now) }
                }
            }
        }
    }

    public func purgeIfDue(now: Date = .now) async {
        if let lastPurge, now.timeIntervalSince(lastPurge) < Self.purgeInterval { return }
        do {
            try await store.purge(retentionDays: retentionDays(), now: now)
            lastPurge = now
        } catch {
            Self.logger.error("Purge failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private nonisolated func refresh(_ target: FeedSnapshot, now: Date) async {
        let request = FetchRequest(url: target.url, etag: target.etag, lastModified: target.lastModified,
                                   allowsInsecureConnection: target.allowsInsecureConnection)
        do {
            switch try await fetcher.fetch(request, now: now) {
            case .notModified:
                try await store.recordNotModified(feedID: target.id, now: now)
            case let .updated(feed, etag, lastModified):
                try await save(feed, etag: etag, lastModified: lastModified, for: target, now: now)
            }
        } catch let error as FetchError {
            let retryAfter: Date? = if case .rateLimited(let date) = error { date } else { nil }
            try? await store.recordFailure(feedID: target.id, errorCode: error.storageCode, retryAfter: retryAfter, now: now)
        } catch FeedStoreError.feedNotFound {
            // The feed was removed while it was being fetched.
        } catch {
            Self.logger.error("Storing feed \(target.id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Stores a fetched feed's items and validators, and its favicon when that is due.
    nonisolated func save(_ feed: ParsedFeed, etag: String?, lastModified: String?, for target: FeedSnapshot, now: Date) async throws {
        try await store.recordSuccess(feedID: target.id, parsed: feed, etag: etag, lastModified: lastModified,
                                      now: now, retentionDays: retentionDays())
        guard target.needsFavicon(now: now) else { return }
        let icon = await favicons.fetch(iconURL: feed.iconURL, siteURL: feed.siteURL ?? target.siteURL,
                                        feedURL: target.url, allowsInsecure: target.allowsInsecureConnection)
        try await store.setFavicon(feedID: target.id, data: icon, now: now)
    }
}

extension FeedSnapshot {
    func needsFavicon(now: Date) -> Bool {
        guard let fetchedAt = faviconFetchedAt else { return true }
        return now.timeIntervalSince(fetchedAt) >= FaviconFetcher.refreshInterval
    }
}
