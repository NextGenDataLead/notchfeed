import Foundation

public enum SubscribeError: Error, Equatable, Sendable {
    /// Not something that can be turned into an http(s) feed URL.
    case invalidURL
    case alreadySubscribed
    /// The http URL doesn't work over https, and the user hasn't allowed plain http for it.
    case httpsUnavailable
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
        } else if let secureURL, let secure = try? await firstFetch(secureURL, allowsInsecure: false) {
            fetched = (secureURL, secure.feed, secure.etag, secure.lastModified)
        } else {
            guard allowsInsecure else { throw .httpsUnavailable }
            let plain = try await firstFetch(url, allowsInsecure: true)
            fetched = (url, plain.feed, plain.etag, plain.lastModified)
        }

        do {
            let id = try await store.addFeed(url: fetched.url, title: fetched.feed.title,
                                             allowsInsecureConnection: fetched.url.scheme?.lowercased() == "http", now: now)
            let snapshot = try await store.snapshot(feedID: id)
            try await save(fetched.feed, etag: fetched.etag, lastModified: fetched.lastModified, for: snapshot, now: now)
            return id
        } catch FeedStoreError.duplicateURL {
            throw .alreadySubscribed
        } catch {
            throw .fetch(.transport(code: URLError.Code.unknown.rawValue))
        }
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
