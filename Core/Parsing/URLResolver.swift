import Foundation

enum URLResolver {
    /// Resolves a possibly relative reference against `base`. Only http and https survive,
    /// so a feed can't make a click open `javascript:`, `file:` or app URLs.
    static func webURL(_ reference: String?, base: URL?) -> URL? {
        guard let resolved = url(reference, base: base),
              let scheme = resolved.scheme?.lowercased(), scheme == "http" || scheme == "https",
              resolved.host() != nil else { return nil }
        return resolved
    }

    /// Resolves a reference without restricting the scheme; used for `xml:base` chains.
    static func url(_ reference: String?, base: URL?) -> URL? {
        guard let trimmed = reference?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }
}
