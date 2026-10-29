import Foundation

/// Atom 1.0 (and the older 0.3 element names where they differ).
enum AtomParser {
    private static let atom: Set<String> = ["http://www.w3.org/2005/Atom", "http://purl.org/atom/ns#", ""]

    static func parse(root: XMLNode, baseURL: URL?, dates: DateParser) -> ParsedFeed {
        let feedBase = base(of: root, inherited: baseURL)
        let items = root.children("entry", in: atom)
            .filter(\.isClosed)
            .compactMap { entry($0, base: base(of: $0, inherited: feedBase), dates: dates) }
        let icon = root.child("icon", in: atom) ?? root.child("logo", in: atom)

        return ParsedFeed(
            title: TextCleaner.plainText(root.child("title", in: atom)?.textContent ?? ""),
            siteURL: alternateLink(of: root, base: feedBase),
            iconURL: URLResolver.webURL(icon?.textContent, base: feedBase),
            items: items
        )
    }

    private static func entry(_ node: XMLNode, base: URL?, dates: DateParser) -> ParsedItem? {
        let link = alternateLink(of: node, base: base)
        let title = TextCleaner.plainText(node.child("title", in: atom)?.textContent ?? "")
        guard !title.isEmpty || link != nil else { return nil }

        let dateText = (node.child("published", in: atom) ?? node.child("issued", in: atom)
            ?? node.child("updated", in: atom) ?? node.child("modified", in: atom))?.textContent
        let id = node.child("id", in: atom)?.textContent.trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedItem(
            guid: id?.isEmpty == false ? id : nil,
            title: title.isEmpty ? (link?.absoluteString ?? "") : title,
            link: link,
            publishedAt: dateText.flatMap(dates.date(from:))
        )
    }

    /// `rel="alternate"` or no rel at all; HTML links win over other types.
    private static func alternateLink(of node: XMLNode, base: URL?) -> URL? {
        let candidates = node.children("link", in: atom).filter { ($0.attribute("rel") ?? "alternate") == "alternate" }
        let preferred = candidates.first { ($0.attribute("type") ?? "text/html").contains("html") } ?? candidates.first
        return URLResolver.webURL(preferred?.attribute("href"), base: base)
    }

    private static func base(of node: XMLNode, inherited: URL?) -> URL? {
        URLResolver.url(node.attribute("base"), base: inherited) ?? inherited
    }
}
