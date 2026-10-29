# Testing

## Automated

```bash
xcodegen generate
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -derivedDataPath build test -destination 'platform=macOS'
```

Tests never hit the network. Fixture feeds live in `Tests/Fixtures/`; the real-world ones are trimmed to three items without article bodies.

| Suite | Covers |
| --- | --- |
| `DateParserTests` | RFC 822 variants (no seconds, named zones, no zone, 2-digit years, full month names), ISO 8601 variants, garbage |
| `FeedParserTests` | RSS 2.0, RSS 1.0, Atom; CDATA and HTML in titles; `xml:base`; Latin-1; bare `&`, HTML entities, truncation, BOM, control characters; HTML pages |
| `DedupeKeyTests`, `FeedStoreTests` | Dedupe by GUID / link / hash, read state kept on re-ingest, retention purge and skip-on-ingest, cascade delete |
| `FeedFetcherTests` | Conditional headers, 304, 429 / 503 Retry-After (seconds and HTTP date, capped), errors, http refused unless allowed |
| `URLSessionHTTPClientTests` | Transport policy on a real `URLSession`: http and other schemes refused, https→http redirects blocked unless allowed, size cap |
| `RefreshCoordinatorTests` | At most 6 fetches in flight, validators and errors stored, Retry-After window skipped, favicons |
| `SubscribeTests` | Input normalisation, https first, per-feed http opt-in, duplicates, non-feed pages |
| `TickerPositionerTests`, `RelativeAgeTests`, `AppSettingsTests` | Bar placement (notch menu bar, Dock, auto-hidden menu bar, external display, fallback), age buckets, setting defaults |

## Manual checklist: V0.1

Run on the MacBook with the notch, preferably with the external display at hand. Build and launch:

```bash
pkill -x NotchFeed; xcodegen generate
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NotchFeed.app
```

To start from an empty database, quit NotchFeed and delete `~/Library/Application Support/NotchFeed/`.

### First launch

- [ ] 1. A thin dark bar runs the full width of the screen, directly under the menu bar, with no gap and no overlap. On a MacBook with a notch it runs below the notch too, not beside it. (Nothing appears beside the notch until the notch panel in V0.4.) It says "No feeds yet. Add some in NotchFeed Settings."
- [ ] 2. The menu bar shows a newspaper icon with no count, and there's no Dock icon.
- [ ] 3. Menu › **Settings…** opens the Settings window in front of other apps, with **General** and **Feeds** tabs.

### Adding feeds (FR-4.1)

- [ ] 4. In **Feeds**, add these 10 one at a time. Each appears in the list with its name within a few seconds, and gets its favicon shortly after:
  `https://feeds.nos.nl/nosnieuwsalgemeen`, `https://hnrss.org/frontpage`, `https://daringfireball.net/feeds/main`, `https://rss.slashdot.org/Slashdot/slashdotMain`, `https://www.theverge.com/rss/index.xml`, `https://feeds.feedburner.com/tweakers/mixed`, `https://feeds.arstechnica.com/arstechnica/index`, `https://feeds.bbci.co.uk/news/rss.xml`, `https://www.nu.nl/rss/Algemeen`, `https://9to5mac.com/feed/`
- [ ] 5. `https://example.com` shows "This address is a web page, not an RSS or Atom feed…" and isn't added.
- [ ] 6. `not a url` shows "Enter a feed address…". Adding `hnrss.org/frontpage` again shows "You already follow this feed."
- [ ] 7. `http://neverssl.com` (a site that serves no feed over https) shows the orange insecure warning, and **Add** stays disabled until **Allow insecure connection for this feed** is ticked. After ticking it and pressing **Add**, it fails with "web page, not a feed" (expected: that site is a page, not a feed). Nothing is added.

### Ticker (FR-1.1, 1.2, 1.8, 1.9)

- [ ] 8. Headlines scroll smoothly from right to left. Each shows favicon, feed name, headline and age ("5m", "2h", "3d"), newest first.
- [ ] 9. Clicking a headline opens it in the default browser. The app you were in keeps focus, and the headline dims within about a second.
- [ ] 10. Open a full-screen app (Safari, green button). The bar isn't shown in that Space; back on the desktop it is. It also shows on every desktop Space.

### Menu bar (FR-5.1, 5.2)

- [ ] 11. The icon shows the unread count, and it drops by one after clicking a headline.
- [ ] 12. The dropdown lists the 20 newest items, unread ones with a dot. Clicking one opens it and marks it read.
- [ ] 13. **Pause Ticker** freezes the scroll and the item becomes **Resume Ticker**; resuming continues from the same spot. Clicking a headline while paused still works.
- [ ] 14. **Refresh Now** updates the "Updated …" times in the Feeds tab.

### General tab (FR-9.1, 9.2, 1.2)

- [ ] 15. **Show feed name** off removes the feed names from the bar; on brings them back.
- [ ] 16. **Show unread count** off leaves only the icon.
- [ ] 17. **Position › Bottom** moves the bar to just above the Dock (try with the Dock hidden and on the left too); **Top** moves it back.
- [ ] 18. With the external display connected, **Display › (external)** moves the bar there. Unplugging moves it to the built-in display, and the setting shows "(not connected)". Plugging back in moves it back.
- [ ] 19. **Open NotchFeed at login**: copy `NotchFeed.app` to `/Applications`, open it from there, turn the toggle on, log out and in. NotchFeed starts. (If macOS asks, allow it in Login Items.) Turn it off again when done.

### Restart and accessibility (FR-4.6, NFR-5, NFR-6)

- [ ] 20. Quit from the menu and reopen. All feeds, headlines and read (dimmed) state are still there, and headlines show within about a second, before any refresh.
- [ ] 21. System Settings › Accessibility › Display › **Reduce motion** on: the bar stops scrolling. Off: it scrolls again.
- [ ] 22. VoiceOver (⌘F5): moving to the bar reads items as "Feed: headline, 5 minutes ago". VO-Space opens the item.

**Done when** (PRD V0.1): 10 feeds added, headlines scroll in a pinned top bar, click opens the browser, and everything survives a restart.
