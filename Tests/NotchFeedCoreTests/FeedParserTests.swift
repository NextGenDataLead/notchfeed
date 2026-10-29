import Foundation
import Testing
@testable import NotchFeedCore

struct FeedParserTests {
    private func parse(_ fixture: String, baseURL: URL? = nil) throws -> ParsedFeed {
        try FeedParser.parse(Fixtures.data(fixture), baseURL: baseURL)
    }

    private func iso(_ string: String) -> Date? { DateParser().date(from: string) }

    // MARK: RSS 2.0

    @Test func parsesRealRSS2WithCDATAAndDutchText() throws {
        let feed = try parse("real-nos-rss2.xml")
        #expect(feed.title == "NOS Nieuws")
        #expect(feed.siteURL == URL(string: "https://nos.nl"))
        #expect(feed.items.count == 3)
        let first = try #require(feed.items.first)
        #expect(first.title == "Duizenden THC-snoepjes in beslag genomen, bestemd voor Nederland")
        #expect(first.link == URL(string: "https://nos.nl/l/2637178"))
        #expect(first.guid == "https://nos.nl/l/2637178")
        #expect(first.publishedAt == iso("2026-10-29T15:38:52Z"))
    }

    @Test func parsesRealRSS2WithAtomSelfLink() throws {
        let feed = try parse("real-hnrss-rss2.xml")
        #expect(feed.title == "Hacker News: Front Page")
        #expect(feed.siteURL == URL(string: "https://news.ycombinator.com/"))
        #expect(feed.items.map(\.title) == [
            "Only 40% of AI-cited statistics trace back to a study",
            "Finland investigate Google over destruction of 250k trees",
            "DoorDash is acquiring Instacart for $17B",
        ])
        #expect(feed.items[0].link == URL(string: "https://trakkr.ai/trakkr-research/zombie-stats"))
    }

    @Test func fallsBackForMissingFields() throws {
        let feed = try parse("rss2-no-guid.xml", baseURL: URL(string: "https://example.com/feed.xml"))
        #expect(feed.iconURL == URL(string: "https://example.com/icon.png"))
        #expect(feed.items.count == 5)
        #expect(feed.items[0].guid == nil)
        #expect(feed.items[0].publishedAt == iso("2026-10-27T09:30:00Z"))
        #expect(feed.items[1].link == URL(string: "https://example.com/posts/2"))
        #expect(feed.items[2].title == "No title here, so the description is used instead.")
        #expect(feed.items[3].link == nil)
        #expect(feed.items[4].link == URL(string: "https://example.com/posts/5"))
    }

    @Test func stripsHTMLAndDecodesEntitiesInTitles() throws {
        let feed = try parse("rss2-cdata-html.xml")
        #expect(feed.title == "CDATA & HTML")
        #expect(feed.items.map(\.title) == [
            "Bold claims & italic news",
            "AT&T buys \u{201C}something\u{201D} \u{2014} again",
        ])
    }

    @Test func readsDublinCoreDate() throws {
        let feed = try parse("rss2-dc-date.xml")
        #expect(feed.items.first?.publishedAt == iso("2026-10-27T08:15:30Z"))
    }

    @Test func toleratesOddDates() throws {
        let dates = try parse("rss2-odd-dates.xml").items.map(\.publishedAt)
        let expected = iso("2026-10-27T09:30:00Z")
        #expect(dates == [expected, expected, expected, expected, expected, nil])
    }

    @Test func honoursDeclaredLatin1Encoding() throws {
        let feed = try parse("rss2-iso-8859-1.xml")
        #expect(feed.title == "Café Latin")
        #expect(feed.items.first?.title == "Naïve résumé")
    }

    // MARK: RSS 1.0

    @Test func parsesRealRSS1() throws {
        let feed = try parse("real-slashdot-rss1.xml")
        #expect(feed.title == "Slashdot")
        #expect(feed.siteURL == URL(string: "https://slashdot.org/"))
        #expect(feed.iconURL == URL(string: "https://a.fsdn.com/sd/topics/topicslashdot.gif"))
        #expect(feed.items.count == 3)
        let first = try #require(feed.items.first)
        #expect(first.title == "'Please Let the Internet Die'")
        #expect(first.link?.absoluteString.hasPrefix("https://tech.slashdot.org/story/26/10/29/052237/") == true)
        #expect(first.guid == first.link?.absoluteString)
        #expect(first.publishedAt == iso("2026-10-29T15:00:00Z"))
    }

    // MARK: Atom

    @Test func parsesRealAtom() throws {
        let feed = try parse("real-daringfireball-atom.xml")
        #expect(feed.title == "Daring Fireball")
        #expect(feed.siteURL == URL(string: "https://daringfireball.net/"))
        #expect(feed.items.count == 3)
        let first = try #require(feed.items.first)
        #expect(first.title == "The Space Shuttle Discovery\u{2019}s Starboard Side \u{2018}s\u{2019} Is Upside Down")
        #expect(first.link?.host() == "www.theautopian.com")
        #expect(first.guid == "tag:daringfireball.net,2026:/linked//6.43663")
        #expect(first.publishedAt == iso("2026-10-29T15:06:56Z"))
    }

    @Test func handlesAtomTextConstructsAndLinkRelations() throws {
        let feed = try parse("atom-html-title.xml")
        #expect(feed.title == "Atom & friends")
        #expect(feed.iconURL == URL(string: "https://example.org/favicon.png"))
        #expect(feed.siteURL == URL(string: "https://example.org/"))
        #expect(feed.items.map(\.title) == ["Escaped HTML title", "Hello XHTML world", "Only updated"])
        #expect(feed.items[2].link == URL(string: "https://example.org/3"))
        #expect(feed.items[1].publishedAt.map { abs($0.timeIntervalSince(iso("2026-10-27T07:00:00Z")!)) < 1 } == true)
        #expect(feed.items[2].publishedAt == iso("2026-10-26T07:00:00Z"))
    }

    @Test func resolvesAtomLinksAgainstXMLBase() throws {
        let feed = try parse("atom-relative-links.xml", baseURL: URL(string: "https://feeds.example.net/rel.atom"))
        #expect(feed.siteURL == URL(string: "https://blog.example.net/"))
        #expect(feed.iconURL == URL(string: "https://blog.example.net/logo.png"))
        #expect(feed.items.map(\.link) == [
            URL(string: "https://blog.example.net/posts/one"),
            URL(string: "https://other.example.net/archive/two"),
        ])
    }

    // MARK: Malformed input

    @Test func repairsUnescapedAmpersandsAndHTMLEntities() throws {
        let feed = try parse("broken-unescaped-ampersand.xml")
        #expect(feed.title == "Tom & Jerry News")
        #expect(feed.items.count == 2)
        #expect(feed.items[0].title == "Salt & pepper \u{E9}dition \u{A9} 2026 & more")
        #expect(feed.items[0].link == URL(string: "https://example.com/posts?id=1&ref=rss"))
    }

    @Test func keepsCompleteItemsOfTruncatedFeed() throws {
        let feed = try parse("broken-truncated.xml")
        #expect(feed.title == "Cut off")
        #expect(feed.items.map(\.guid) == ["t1", "t2"])
    }

    @Test func skipsBOMLeadingWhitespaceAndControlCharacters() throws {
        let feed = try parse("broken-bom-leading-whitespace.xml")
        #expect(feed.title == "BOM first")
        #expect(feed.items.map(\.title) == ["After a BOM", "Stray control char and ref"])
    }

    @Test func rejectsHTMLPage() throws {
        #expect(throws: FeedParserError.notAFeed) {
            try parse("not-a-feed.html")
        }
    }

    @Test func rejectsEmptyAndNonXMLData() {
        #expect(throws: FeedParserError.self) { try FeedParser.parse(Data(), baseURL: nil) }
        #expect(throws: FeedParserError.self) { try FeedParser.parse(Data("{\"json\": true}".utf8), baseURL: nil) }
    }

    @Test func usesHostAsTitleWhenFeedHasNone() throws {
        let xml = #"<rss version="2.0"><channel><item><title>A</title></item></channel></rss>"#
        let feed = try FeedParser.parse(Data(xml.utf8), baseURL: URL(string: "https://news.example.com/rss"))
        #expect(feed.title == "news.example.com")
    }
}
