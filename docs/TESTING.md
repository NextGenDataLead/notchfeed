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
| `FullScreenDetectorTests` | Full screen vs. zoomed window (window lists measured on macOS 26), Space-switch animation, external display, auto-hidden menu bar |

## Manual checklist: V0.1

Run on the MacBook with the notch, preferably with the external display at hand. Build and launch:

```bash
pkill -x NotchFeed; xcodegen generate
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NotchFeed.app
```

To start from an empty database, quit NotchFeed and delete `~/Library/Application Support/NotchFeed/`.

**Current run:** started 2026-10-29 on macOS 26.5.2, MacBook with notch. Ticked items passed; notes in *italics* say what was found and fixed during the run.

### First launch

- [x] 1. A thin dark bar runs the full width of the screen, directly under the menu bar, with no gap and no overlap. On a MacBook with a notch it runs below the notch too, not beside it. (Nothing appears beside the notch until the notch panel in V0.4.) It says "No feeds yet. Add some in NotchFeed Settings."
  *Check wording fixed: the bar runs below the notch, not beside it.*
- [x] 2. The menu bar shows a newspaper icon with no count, and there's no Dock icon.
- [x] 3. Menu › **Settings…** opens the Settings window in front of other apps, with **General** and **Feeds** tabs.

### Adding feeds (FR-4.1)

- [x] 4. In **Feeds**, add these 10 one at a time. Each appears in the list with its name within a few seconds, and gets its favicon shortly after:
  `https://feeds.nos.nl/nosnieuwsalgemeen`, `https://hnrss.org/frontpage`, `https://daringfireball.net/feeds/main`, `https://rss.slashdot.org/Slashdot/slashdotMain`, `https://www.theverge.com/rss/index.xml`, `https://tweakers.net/feeds/mixed.xml`, `https://feeds.arstechnica.com/arstechnica/index`, `https://feeds.bbci.co.uk/news/rss.xml`, `https://www.nu.nl/rss/Algemeen`, `https://9to5mac.com/feed/`
  *Passed with the old FeedBurner Tweakers URL, which stopped updating in April 2025 (all items past retention, so 0 headlines). Replaced by Tweakers' own feed, which was removed and re-added without problems (40 headlines).*
- [x] 5. `https://example.com` shows "This address is a web page, not an RSS or Atom feed…" and isn't added.
  *First try showed "The feed couldn't be read": HTML5 pages weren't recognised. Fixed in 799d746; retest passed.*
- [x] 6. `not a url` shows "Enter a feed address…". Adding `hnrss.org/frontpage` again shows "You already follow this feed."
- [x] 7. `http://neverssl.com` (a site that serves no feed over https) shows the orange insecure warning, and **Add** stays disabled until **Allow insecure connection for this feed** is ticked. After ticking it and pressing **Add**, it fails with "web page, not a feed" (expected: that site is a page, not a feed). Nothing is added.

### Ticker (FR-1.1, 1.2, 1.8, 1.9)

- [x] 8. Headlines scroll smoothly from right to left. Each shows favicon, feed name, headline and age ("5m", "2h", "3d"), newest first.
- [x] 9. Clicking a headline opens it in the default browser. The app you were in keeps focus, and the headline dims within about a second.
  *First try: the browser opened but the headline didn't dim. The item was marked read, but the bar held every change until the end of its loop, which takes minutes with 50 headlines. Read state is now applied at once (a70ca49); retest passed.*
- [x] 10. Open a full-screen app (Safari, green button). The bar isn't shown in that Space; back on the desktop it is. It also shows on every desktop Space.
  *First try: the bar showed over full-screen Safari and covered its toolbar, because macOS 26 puts the panel on full-screen Spaces anyway. The ticker now detects full screen from the window list and hides (see DECISIONS.md). Fixed in a70ca49; retest with Safari passed.*
  *Also seen: the bar covers the title bar of a window that fills the screen (VS Code, or any window after a double-click on its title bar), so the window can't be dragged there. This is expected in V0.1, because macOS can't reserve screen space for a bar (PRD risks). Workarounds: Position › Bottom, or move the window from its Window menu. Overlap handling is FR-1.6 (V0.2).*

### Menu bar (FR-5.1, 5.2)

- [x] 11. The icon shows the unread count as a small badge in its bottom-right corner ("99+" above 99), readable in light and dark mode. The icon stays visible beside the notch. Below 100 unread, the number drops by one after clicking a headline.
  *Text count ("296") made the item too wide and macOS hid it beside the notch. Now a badge (18f97d1): visible and readable, confirmed 2026-10-30. With 296 unread the badge stays at "99+", so the count dropping after a click was checked in the database instead: 5 clicks, 5 items read.*
- [x] 12. The dropdown lists the 20 newest items, unread ones with a dot. Clicking one opens it and marks it read.
- [x] 13. **Pause Ticker** freezes the scroll and the item becomes **Resume Ticker**; resuming continues from the same spot. Clicking a headline while paused still works.
- [x] 14. **Refresh Now** updates the "Updated …" times in the Feeds tab.

### General tab (FR-9.1, 9.2, 1.2)

- [x] 15. **Show feed name** off removes the feed names from the bar; on brings them back, both within about a second.
  *First try: it worked, but only at the end of the scroll loop. Setting changes now apply at once, with the item at the left edge kept in place (4416645); retest passed.*
- [x] 16. **Show unread count** off leaves only the icon.
- [x] 17. **Position › Bottom** moves the bar to just above the Dock (try with the Dock hidden and on the left too); **Top** moves it back.
- [ ] 18. With the external display connected, **Display › (external)** moves the bar there. Unplugging moves it to the built-in display, and the setting shows "(not connected)". Plugging back in moves it back.
  *Skipped for now (2026-10-30).*
- [ ] 19. **Open NotchFeed at login**: copy `NotchFeed.app` to `/Applications`, open it from there, turn the toggle on, log out and in. NotchFeed starts. (If macOS asks, allow it in Login Items.) Turn it off again when done.
  *Skipped for now (2026-10-30).*

### Restart and accessibility (FR-4.6, NFR-5, NFR-6)

- [x] 20. Quit from the menu and reopen. All feeds, headlines and read (dimmed) state are still there, and headlines show within about a second, before any refresh.
- [x] 21. Turn on **Reduce motion** in System Settings (type "Reduce motion" in the search field; it's under Accessibility). The bar stops scrolling. Turn it off: the bar scrolls again.
- [x] 22. VoiceOver reads ticker items. Pause the ticker (menu › **Pause Ticker**) so items stay put. Turn on VoiceOver in System Settings › Accessibility › VoiceOver. Point the mouse at a headline and press Control-Option-Command-F5 (add fn if the F-keys control brightness and volume) to move the VoiceOver cursor there. It reads "Feed: headline, 5 minutes ago". Control-Option-Space opens the item. Turn VoiceOver off and resume the ticker.

**Done when** (PRD V0.1): 10 feeds added, headlines scroll in a pinned top bar, click opens the browser, and everything survives a restart.
