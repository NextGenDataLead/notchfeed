import AppKit
import NotchFeedCore
import Observation
import os
import SwiftData

/// One headline as the ticker and the menu show it.
struct HeadlineEntry: Identifiable, Hashable {
    /// The item's dedupe key.
    let id: String
    let title: String
    let feedTitle: String
    let favicon: NSImage?
    let link: URL?
    let date: Date
    let isRead: Bool
}

/// One feed as the Feeds settings tab shows it.
struct FeedRow: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: URL
    let favicon: NSImage?
    let lastFetchedAt: Date?
    let error: FetchError?
    let retryAfter: Date?
    let allowsInsecureConnection: Bool
}

/// Main-actor view of the store shared by the ticker and the menu bar. Reloads after every save of
/// any model context, so writes from the background `FeedStore` show up without relying on `@Query`.
@MainActor
@Observable
final class AppModel {
    private static let reloadDelay: Duration = .milliseconds(250)
    private static let clockInterval: TimeInterval = 60
    private static let logger = Logger(subsystem: "com.nextgendatalead.NotchFeed", category: "model")

    private(set) var headlines: [HeadlineEntry] = []
    private(set) var unreadCount = 0
    private(set) var feeds: [FeedRow] = []
    var hasFeeds: Bool { !feeds.isEmpty }
    /// Ticks every minute so relative ages stay current.
    private(set) var now = Date.now
    /// FR-5.2: stops the scroll; not kept across restarts.
    var isTickerPaused = false

    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let store: FeedStore
    @ObservationIgnored let coordinator: RefreshCoordinator
    @ObservationIgnored private var faviconCache: [UUID: (data: Data, image: NSImage)] = [:]
    @ObservationIgnored private var reloadTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var clock: Timer?

    init(container: ModelContainer, store: FeedStore, coordinator: RefreshCoordinator) {
        self.container = container
        self.store = store
        self.coordinator = coordinator
    }

    func start() {
        reload()
        observers.append(NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleReload() }
        })
        clock = Timer.scheduledTimer(withTimeInterval: Self.clockInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = .now }
        }
        clock?.tolerance = 5
        Task { await coordinator.start() }
    }

    func refreshNow() {
        Task { await coordinator.refreshAll() }
    }

    /// FR-1.9: opens the item in the default browser and marks it read.
    func open(_ entry: HeadlineEntry) {
        if let link = entry.link {
            NSWorkspace.shared.open(link)
        }
        Task {
            do {
                try await store.markRead(dedupeKey: entry.id)
            } catch {
                Self.logger.error("Marking item read failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// FR-4.1: validates and adds a feed; the Feeds tab shows the error if it fails.
    func subscribe(_ input: String, allowsInsecure: Bool) async throws(SubscribeError) {
        try await coordinator.subscribe(to: input, allowsInsecure: allowsInsecure)
    }

    func removeFeed(_ id: UUID) {
        Task {
            do {
                try await store.deleteFeed(id: id)
            } catch {
                Self.logger.error("Removing feed failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Applies a changed retention setting right away instead of at the next daily purge.
    func applyRetention() {
        Task {
            do {
                try await store.purge(retentionDays: AppSettings.retentionDays())
            } catch {
                Self.logger.error("Purge failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(for: Self.reloadDelay)
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    /// Reads through a fresh context so values saved by other contexts are never stale.
    func reload() {
        let context = ModelContext(container)
        do {
            var descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.sortDate, order: .reverse)])
            descriptor.fetchLimit = AppDefaults.tickerItemLimit
            let items = try context.fetch(descriptor)
            let entries = items.map(entry)
            if entries != headlines { headlines = entries }

            let unread = try context.fetchCount(FetchDescriptor<Item>(predicate: #Predicate { !$0.isRead }))
            if unread != unreadCount { unreadCount = unread }

            let rows = try context.fetch(FetchDescriptor<Feed>())
                .map(row)
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if rows != feeds { feeds = rows }
        } catch {
            Self.logger.error("Loading headlines failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func entry(_ item: Item) -> HeadlineEntry {
        HeadlineEntry(
            id: item.dedupeKey,
            title: item.title,
            feedTitle: item.feed?.title ?? "",
            favicon: item.feed.flatMap(favicon),
            link: item.link,
            date: item.sortDate,
            isRead: item.isRead
        )
    }

    private func row(_ feed: Feed) -> FeedRow {
        FeedRow(
            id: feed.id,
            title: feed.title,
            url: feed.url,
            favicon: favicon(for: feed),
            lastFetchedAt: feed.lastFetchedAt,
            error: feed.lastError.flatMap(FetchError.init(storageCode:)),
            retryAfter: feed.retryAfter,
            allowsInsecureConnection: feed.allowsInsecureConnection
        )
    }

    /// Reuses the same NSImage while the data is unchanged, so entries compare equal between reloads.
    private func favicon(for feed: Feed) -> NSImage? {
        guard let data = feed.faviconData else { return nil }
        if let cached = faviconCache[feed.id], cached.data == data { return cached.image }
        guard let image = NSImage(data: data) else { return nil }
        faviconCache[feed.id] = (data, image)
        return image
    }
}
