import Foundation
import ImageIO

/// FR-1.8: the feed's own icon first, then `/favicon.ico` on the site. Plain http icon URLs are
/// upgraded to https unless the feed allows http. No third-party favicon service (NFR-7).
public struct FaviconFetcher: Sendable {
    public static let refreshInterval: TimeInterval = 7 * 24 * 60 * 60
    static let maxBytes = 256 * 1024

    private let client: any HTTPClient

    public init(client: any HTTPClient) {
        self.client = client
    }

    public func fetch(iconURL: URL?, siteURL: URL?, feedURL: URL, allowsInsecure: Bool) async -> Data? {
        for candidate in candidates(iconURL: iconURL, siteURL: siteURL, feedURL: feedURL, allowsInsecure: allowsInsecure) {
            if let data = await image(at: candidate, allowsInsecure: allowsInsecure) {
                return data
            }
        }
        return nil
    }

    private func candidates(iconURL: URL?, siteURL: URL?, feedURL: URL, allowsInsecure: Bool) -> [URL] {
        let site = siteURL ?? feedURL
        let favicon = URL(string: "/favicon.ico", relativeTo: site)?.absoluteURL
        let urls = [iconURL, favicon].compactMap { $0.map { allowsInsecure ? $0 : upgradedToHTTPS($0) } }
        return urls.reduce(into: []) { unique, url in
            if !unique.contains(url) { unique.append(url) }
        }
    }

    private func upgradedToHTTPS(_ url: URL) -> URL {
        guard url.scheme?.lowercased() == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url }
        components.scheme = "https"
        return components.url ?? url
    }

    private func image(at url: URL, allowsInsecure: Bool) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue(FeedFetcher.userAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await client.data(for: request, allowsInsecure: allowsInsecure),
              (200..<300).contains(response.statusCode),
              !data.isEmpty, data.count <= Self.maxBytes,
              Self.isImage(data) else { return nil }
        return data
    }

    static func isImage(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 0 && CGImageSourceGetType(source) != nil
    }
}
