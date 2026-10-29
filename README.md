# NotchFeed

NotchFeed is a native, open-source macOS app that keeps the latest headlines from your RSS and Atom feeds in view without opening a reader. It shows them in a ticker bar, a notch panel, a menu bar item and alerts.

It runs entirely on your Mac: there's no account, no tracking and no server. MIT licence.

> **Status:** V0.1, the walking skeleton. The notch panel, alerts, ticker styles and OPML import follow in later versions; see the release plan in [PRD.md](PRD.md).

## What V0.1 does

- **Ticker bar.** A thin bar under the menu bar (or above the Dock) scrolls the 50 newest headlines with favicon, feed name and age. Click a headline to open it in your browser; read items are dimmed. The bar stays off full-screen apps.
- **Menu bar item.** Shows the unread count and the 20 newest items, with Refresh Now, Pause Ticker, Settings and Quit.
- **Feeds.** Add a feed by its URL. NotchFeed checks it before saving, prefers https, and only uses plain http for a feed if you allow it.
- **Fetching.** RSS 2.0, RSS 1.0 and Atom, with a lenient parser for broken feeds. NotchFeed uses conditional requests, honours Retry-After, runs at most 6 fetches at once, and refreshes every 15 minutes.
- **Storage.** Feeds, headlines and read state survive restarts. Items older than 30 days (configurable) are removed.
- **Launch at login**, Reduce Motion support and VoiceOver labels.

## Requirements

- macOS 14 Sonoma or later
- Xcode 26 or later (the full app, not just the Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Build from source

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NotchFeed.app
```

Run the tests:

```bash
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -derivedDataPath build test -destination 'platform=macOS'
```

The Xcode project is generated from `project.yml` and isn't committed. Builds get an ad-hoc signature only, so NotchFeed is meant to be built and run locally.

NotchFeed is an accessory app, so it has no Dock icon. Look for the newspaper icon in the menu bar and choose **Settings…** to add feeds. For **Open at login**, copy the app to `/Applications` first.

Data lives in `~/Library/Application Support/NotchFeed/`.

## Privacy

NotchFeed only connects to the feeds you add and their sites (for favicons). It has no analytics. Plain http is refused unless you allow it for a specific feed.

## Licence

MIT. See [LICENSE](LICENSE).
