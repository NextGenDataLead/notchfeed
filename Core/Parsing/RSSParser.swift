import Foundation

/// RSS 2.0 (root `rss`) and RSS 1.0 (root `rdf:RDF`).
enum RSSParser {
    /// RSS 2.0 has no namespace; RSS 1.0 uses its own. Some feeds mix them up, so accept both.
    private static let rss: Set<String> = ["", "http://purl.org/rss/1.0/", "http://backend.userland.com/rss2"]
    private static let dublinCore: Set<String> = ["http://purl.org/dc/elements/1.1/"]
    private static let fallbackTitleLength = 140

    static func parse(root: XMLNode, baseURL: URL?, dates: DateParser) -> ParsedFeed {
        let channel = root.child("channel", in: rss)
        let siteURL = URLResolver.webURL(channel?.child("link", in: rss)?.textContent, base: baseURL)
        let itemBase = siteURL ?? baseURL

        // RSS 1.0 puts items and the image next to the channel instead of inside it.
        let itemNodes = (channel?.children("item", in: rss) ?? []) + root.children("item", in: rss)
        let items = itemNodes
            .filter(\.isClosed)
            .compactMap { item($0, base: itemBase, dates: dates) }

        let image = channel?.child("image", in: rss)
        let iconReference = image?.child("url", in: rss)?.textContent
            ?? root.child("image", in: rss)?.child("url", in: rss)?.textContent
            ?? image?.attribute("resource")

        return ParsedFeed(
            title: TextCleaner.plainText(channel?.child("title", in: rss)?.textContent ?? ""),
            siteURL: siteURL,
            iconURL: URLResolver.webURL(iconReference, base: itemBase),
            items: items
        )
    }

    private static func item(_ node: XMLNode, base: URL?, dates: DateParser) -> ParsedItem? {
        let guidNode = node.child("guid", in: rss)
        let guid = (guidNode?.textContent ?? node.attribute("about"))?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var link = URLResolver.webURL(node.child("link", in: rss)?.textContent, base: base)
        if link == nil, guidNode?.attribute("isPermaLink")?.lowercased() != "false" {
            link = URLResolver.webURL(guid, base: nil)
        }

        let title = TextCleaner.plainText(node.child("title", in: rss)?.textContent ?? "")
        let displayTitle = title.isEmpty ? descriptionTitle(node) : title
        guard !displayTitle.isEmpty || link != nil else { return nil }

        let dateText = node.child("pubDate", in: rss)?.textContent ?? node.child("date", in: dublinCore)?.textContent
        return ParsedItem(
            guid: guid?.isEmpty == false ? guid : nil,
            title: displayTitle.isEmpty ? (link?.absoluteString ?? "") : displayTitle,
            link: link,
            publishedAt: dateText.flatMap(dates.date(from:))
        )
    }

    private static func descriptionTitle(_ node: XMLNode) -> String {
        let text = TextCleaner.plainText(node.child("description", in: rss)?.textContent ?? "")
        guard text.count > fallbackTitleLength else { return text }
        return text.prefix(fallbackTitleLength).trimmingCharacters(in: .whitespaces) + "\u{2026}"
    }
}
