import Foundation

public enum SubscribeError: Error, Equatable, Sendable {
    /// Not something that can be turned into an http(s) feed URL.
    case invalidURL
    case alreadySubscribed
    /// The http URL doesn't work over https (with the https error), and plain http isn't allowed for it.
    case httpsUnavailable(FetchError)
    case fetch(FetchError)
}

/// Turns what the user typed into a feed URL.
enum FeedURLInput {
    static func normalize(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }

        // feed://host/path and feed:https://host/path are old browser conventions.
        if text.lowercased().hasPrefix("feed:") {
            text = String(text.dropFirst("feed:".count))
            text = text.hasPrefix("//") ? "https:" + text : text
        }
        if !text.contains("://") {
            text = "https://" + text
        }

        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host(), host.contains(".") || host == "localhost" else { return nil }
        return url
    }

    static func httpsVariant(of url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        components.scheme = "https"
        return components.url
    }
}

extension RefreshCoordinator {
    /// FR-4.1: checks that the URL is a working feed before saving it, then stores its first items.
    /// For an http URL the https version is tried first; plain http is used only when allowed.
    @discardableResult
    public func subscribe(to input: String, allowsInsecure: Bool, now: Date = .now) async throws(SubscribeError) -> UUID {
        guard let url = FeedURLInput.normalize(input) else { throw .invalidURL }
        let isPlainHTTP = url.scheme?.lowercased() == "http"
        let secureURL = isPlainHTTP ? FeedURLInput.httpsVariant(of: url) : url

        do {
            if try await store.hasFeed(withAnyOf: [url, secureURL].compactMap { $0 }) { throw SubscribeError.alreadySubscribed }
        } catch let error as SubscribeError {
            throw error
        } catch {
            throw .fetch(.transport(code: URLError.Code.unknown.rawValue))
        }

        let fetched: (url: URL, feed: ParsedFeed, etag: String?, lastModified: String?)
        if !isPlainHTTP {
            let secure = try await firstFetch(url, allowsInsecure: false)
            fetched = (url, secure.feed, secure.etag, secure.lastModified)
        } else {
            var httpsError = FetchError.unsupportedURL
            if let secureURL {
                do throws(SubscribeError) {
                    let secure = try await firstFetch(secureURL, allowsInsecure: false)
                    return try await add((secureURL, secure.feed, secure.etag, secure.lastModified), now: now)
                } catch {
                    if case .fetch(let reason) = error { httpsError = reason }
                }
            }
            guard allowsInsecure else { throw .httpsUnavailable(httpsError) }
            let plain = try await firstFetch(url, allowsInsecure: true)
            fetched = (url, plain.feed, plain.etag, plain.lastModified)
        }
        return try await add(fetched, now: now)
    }

    /// Saves the feed and its first items. Once the feed is saved, later problems are logged rather
    /// than reported, so the user never sees "failed" for a feed that was added. The favicon loads in
    /// the background so it doesn't hold up the Add button.
    private func add(_ fetched: (url: URL, feed: ParsedFeed, etag: String?, lastModified: String?), now: Date) async throws(SubscribeError) -> UUID {
        let id: UUID
        do {
            id = try await store.addFeed(url: fetched.url, title: fetched.feed.title,
                                         allowsInsecureConnection: fetched.url.scheme?.lowercased() == "http", now: now)
        } catch FeedStoreError.duplicateURL {
            throw .alreadySubscribed
        } catch {
            Self.logger.error("Adding feed failed: \(error.localizedDescription, privacy: .public)")
            throw .fetch(.transport(code: URLError.Code.unknown.rawValue))
        }

        do {
            try await store.recordSuccess(feedID: id, parsed: fetched.feed, etag: fetched.etag, lastModified: fetched.lastModified,
                                          now: now, retentionDays: retentionDays())
            let snapshot = try await store.snapshot(feedID: id)
            Task { try? await saveFavicon(for: fetched.feed, target: snapshot, now: now) }
        } catch {
            Self.logger.error("Storing first items of feed \(id, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        return id
    }

    private func firstFetch(_ url: URL, allowsInsecure: Bool) async throws(SubscribeError) -> (feed: ParsedFeed, etag: String?, lastModified: String?) {
        do throws(FetchError) {
            switch try await fetcher.fetch(FetchRequest(url: url, allowsInsecureConnection: allowsInsecure)) {
            case let .updated(feed, etag, lastModified): return (feed, etag, lastModified)
            case .notModified: throw FetchError.httpStatus(304)
            }
        } catch {
            throw .fetch(error)
        }
    }
}
