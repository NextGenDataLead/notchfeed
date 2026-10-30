# NotchFeed — PRD (macOS RSS ticker)

Oct 29, 2026 · @Jay

## Overview

NotchFeed is a native, open-source macOS app that keeps the latest headlines from many RSS and Atom feeds in view, through a ticker bar, a notch panel and alerts, without opening a reader. It is built for one person's needs first; porting to Windows and Linux is a later decision (see Backlog). The app is named NotchFeed.

**Problem.** macOS has no RSS widget, and desktop widgets sit behind open windows. Existing reader apps need to be opened, and existing ticker apps are paid, limited (Newsriver: 5 feeds on its free tier) or abandoned.

**Goals**

- Headlines stay visible at a glance, in whatever way the user picks: continuous scroll, one at a time, or on demand.
- Important items (by feed or keyword) reach the user right away; everything else stays ambient.
- Works well with many feeds (50 to 200) without spam, high CPU or battery drain.
- Makes good use of the MacBook notch, with a sensible fallback on displays without one.
- Stays out of the way: hides during screen sharing, full-screen video and Focus modes.
- Fully local: no account, no tracking, no server. MIT licence.

**Non-goals for V1**

- A full article reading view (the browser does that).
- Sync with Feedbin, Feedly, FreshRSS or other services.
- AI summaries, iOS app, Windows or Linux builds.
- Mac App Store distribution.

## Target user and context

The primary user is the author: one person on a MacBook with a notch, sometimes with an external display.

| Factor | Value | Design consequence |
| --- | --- | --- |
| Hardware | MacBook with notch, plus external monitor at times | Notch panel is a first-class surface; every surface needs a no-notch fallback |
| Feed count | Many (assume 50 to 200) | Per-feed priority, batching, rate limits and efficient fetching are core, not extras |
| Other readers | None, this is the only reader | Owns feed management, read state and OPML import/export |
| Alert triggers | Specific feeds and keywords | Priority per feed plus a global keyword list |
| Modes | Different preferences at different times | Every display behaviour is a setting, with presets |

All behaviours described as options in this PRD are user settings with a sensible default.

## Key concepts

**Notch vs Dynamic Island.** The notch is the hardware cutout for the camera at the top centre of newer MacBooks. Dynamic Island is Apple's iPhone interface that turns its cutout into a living black pill that expands for alerts and activities. Macs have no Dynamic Island; apps such as NotchNest, Boring Notch and NotchNook draw a black shape that blends with the notch and expands from it, imitating the idea.

For NotchFeed this gives three things:

- **A home for alerts.** A new item can drop out of the notch as a panel, which looks native and reuses dead screen space instead of covering windows.
- **An idle indicator.** While closed, small "ears" beside the notch can show an unread count or a feed favicon.
- **A hover hub.** Hovering the notch opens a panel with the latest headlines, in the style of NotchNest.

**Display surfaces.** The app has four surfaces, each enabled separately:

1. **Ticker bar**: a thin bar with headlines, at the top under the menu bar or at the bottom above the Dock.
2. **Notch panel**: expands from the notch on hover, click, hotkey or new alert.
3. **Menu bar item**: icon with unread count and a dropdown with recent items and controls.
4. **Alerts**: native macOS notifications in V1; a custom drop-in from the notch later.

**Unpinned behaviours, ranked.** When the ticker bar is not pinned, it can behave in these ways. All are options; the first is the default.

| Rank | Behaviour | Why |
| --- | --- | --- |
| 1 | Show on new items, then auto-hide after N seconds | Only appears when there is something to see; zero cost the rest of the time |
| 2 | Hotkey toggle | Instant, precise, no accidental triggers |
| 3 | Hover the notch or menu bar icon to reveal | Discoverable and mouse-driven; works with the notch panel |
| 4 | Periodic peek: show for N seconds every M minutes | Ambient awareness without permanent space use |
| 5 | Reveal at screen edge (hot zone) | Familiar from the Dock, but clashes with the menu bar in full-screen apps and triggers by accident |

Behaviours 1 to 4 can be combined; 5 is off by default.

## Functional requirements

IDs (FR-x) are stable so the release plan and Claude Code tasks can reference them. Each row lists the target version.

### FR-1 Ticker bar

| ID | Requirement | Version |
| --- | --- | --- |
| FR-1.1 | Thin always-on-top bar (floating window level, visible on all Spaces, hidden over full-screen apps by default, where only the notch panel shows) | V0.1 |
| FR-1.2 | Position: top under menu bar (default), or bottom above Dock; choice of display when several are connected | V0.1 |
| FR-1.3 | Display style: continuous scroll, one-at-a-time with fade, one-at-a-time with slide, or static list of latest N | V0.2 |
| FR-1.4 | Scroll speed, rotation interval and pause-on-hover settings | V0.2 |
| FR-1.5 | Pinned or unpinned; unpinned behaviours from Key concepts, combinable | V0.2 |
| FR-1.6 | Overlap handling: overlap windows, thin and translucent (opacity slider), or bottom placement | V0.2 |
| FR-1.7 | Height, font size and theme (system, light, dark) | V0.2 |
| FR-1.8 | Each item shows feed favicon, feed name (optional), headline and relative age | V0.1 |
| FR-1.9 | Click opens the item in the default browser and marks it read; right-click menu: mark read, save for later, mute feed, copy link | V0.1 / V0.3 |
| FR-1.10 | Filter what the ticker shows: all, unread only, or selected feeds or folders | V0.3 |
| FR-1.11 | Mouse-dodge: when the pointer moves into the bar, it fades out and lets clicks through to the window below. Resting on it for about 0.6 s, or holding ⌥, makes it solid and clickable again, with a visible cue. Each trigger can be turned off | V0.2 |

### FR-2 Notch panel

| ID | Requirement | Version |
| --- | --- | --- |
| FR-2.1 | Black panel that expands from the notch with a spring animation and collapses back | V0.4 |
| FR-2.2 | Trigger: hover, click or global hotkey (setting) | V0.4 |
| FR-2.3 | Content: latest N items, grouped by feed or time, with unread markers | V0.4 |
| FR-2.4 | Idle state: off, unread count in the notch "ears", or favicon of the newest item | V0.4 |
| FR-2.5 | No-notch fallback: same panel drops from the top centre of the active display | V0.4 |
| FR-2.6 | Keyboard navigation in the panel (arrows, Return to open, E to mark read, S to save) | V0.5 |

### FR-3 Alerts

| ID | Requirement | Version |
| --- | --- | --- |
| FR-3.1 | Native macOS notifications for items from alert-priority feeds or matching keywords | V0.3 |
| FR-3.2 | Batching: several new items from one feed in one fetch become one notification ("5 new from X") | V0.3 |
| FR-3.3 | Rate limit: max N alerts per M minutes, overflow goes to a summary | V0.3 |
| FR-3.4 | Quiet hours and respect for macOS Focus (native notifications get this for free) | V0.3 |
| FR-3.5 | Notification actions: Open, Mark read, Save for later | V0.3 |
| FR-3.6 | Custom drop-in from the notch with image, summary and keyboard actions, as an alternative to native alerts | V1.1 |

### FR-4 Feeds, priority and keywords

| ID | Requirement | Version |
| --- | --- | --- |
| FR-4.1 | Add a feed by feed URL, or by website URL with automatic feed discovery | V0.1 / V0.3 |
| FR-4.2 | Folders (groups) for feeds | V0.3 |
| FR-4.3 | Priority per feed: Alert, Ticker only, Muted; default per folder | V0.3 |
| FR-4.4 | Global keyword list (case-insensitive, whole word optional); a match raises an item to Alert | V0.3 |
| FR-4.5 | Mute keywords: items matching are hidden everywhere | V0.5 |
| FR-4.6 | Read state, deduplication by GUID or link, retention limit (default 30 days, configurable) | V0.1 |
| FR-4.7 | Save for later list | V0.3 |
| FR-4.8 | OPML import and export | V0.3 |
| FR-4.9 | Feed health: show last fetch, errors, and feeds that have not updated in N days | V0.5 |

### FR-5 Menu bar item

| ID | Requirement | Version |
| --- | --- | --- |
| FR-5.1 | Icon with optional unread count | V0.1 |
| FR-5.2 | Dropdown: last 20 items, Refresh now, Pause ticker, Snooze (30 min, 1 h, until tomorrow), Settings, Quit | V0.1 / V0.3 |

### FR-6 Hover preview

| ID | Requirement | Version |
| --- | --- | --- |
| FR-6.1 | Hovering an item for 500 ms shows a popover with title, feed, date, summary and image if present | V0.3 |

### FR-7 Auto-hide and privacy

| ID | Requirement | Version |
| --- | --- | --- |
| FR-7.1 | Hide ticker and drop-ins while the screen is being shared or recorded | V0.3 |
| FR-7.2 | Hide when a full-screen app is in front (setting, with an allow list) | V0.3 |
| FR-7.3 | Hide or quiet down while a Focus mode is on (setting per surface) | V0.3 |
| FR-7.4 | Manual hide-all hotkey | V0.2 |

### FR-8 Fetching

| ID | Requirement | Version |
| --- | --- | --- |
| FR-8.1 | Parse RSS 2.0, RSS 1.0 and Atom; tolerate common malformed XML and date formats; JSON Feed later | V0.1 |
| FR-8.2 | Conditional requests (ETag, If-Modified-Since); honour HTTP 304 and 429 Retry-After | V0.1 |
| FR-8.3 | Refresh interval global (default 15 min) and per feed; spread fetches over the interval instead of all at once | V0.3 |
| FR-8.4 | Back-off on errors; pause fetching on low power mode or when offline | V0.3 |
| FR-8.5 | Concurrency limit (e.g. 6 parallel requests) | V0.1 |

### FR-9 Settings and presets

| ID | Requirement | Version |
| --- | --- | --- |
| FR-9.1 | Native settings window with tabs: General, Ticker, Notch, Alerts, Feeds, Keywords, Shortcuts | V0.1 onward |
| FR-9.2 | Launch at login | V0.1 |
| FR-9.3 | Presets that switch many settings at once, e.g. Focus (notch only, alerts for keywords), Ambient (pinned ticker, fade), News desk (scrolling ticker, all alerts); selectable from the menu bar | V0.5 |
| FR-9.4 | Global hotkeys configurable | V0.2 |

## Non-functional requirements and architecture

NotchFeed is a native Swift app with SwiftUI views hosted in AppKit panels, local storage, and as few dependencies as possible.

### Non-functional requirements

| ID | Requirement | Target |
| --- | --- | --- |
| NFR-1 | Idle CPU with ticker visible and static style | under 1% on Apple Silicon |
| NFR-2 | CPU while scrolling | under 5%, smooth at display refresh rate (60 or 120 Hz) |
| NFR-3 | Memory with 200 feeds and 30 days of items | under 150 MB |
| NFR-4 | Energy impact in Activity Monitor | "Low" in normal use |
| NFR-5 | Startup to first headlines (cached) | under 1 s |
| NFR-6 | Accessibility | VoiceOver labels on all items; Reduce Motion switches scroll to static or fade |
| NFR-7 | Privacy | No analytics, no network calls other than feed fetches and favicons |
| NFR-8 | Localisation | English in V1; all strings in a String Catalog so Dutch can follow |
| NFR-9 | Minimum OS | macOS 14 Sonoma (notch APIs and SwiftData available); tested on macOS 26 |

### Tech stack

| Area | Choice | Notes |
| --- | --- | --- |
| Language and UI | Swift 6, SwiftUI inside AppKit `NSPanel` windows | Panels are non-activating, so clicking the ticker does not steal focus |
| Always on top | Panel level above normal windows; `collectionBehavior` canJoinAllSpaces + fullScreenAuxiliary | Gives FR-1.1 |
| Notch geometry | `NSScreen.safeAreaInsets`, `auxiliaryTopLeftArea` and `auxiliaryTopRightArea` | Detects notch size per display; fallback when absent |
| Menu bar | SwiftUI `MenuBarExtra` | App runs as an accessory app (no Dock icon by default) |
| Storage | SwiftData (SQLite underneath) | Feeds, items, read state, settings; switch to GRDB if performance requires |
| Feed parsing | Own parser on Foundation `XMLParser` | FeedKit (MIT) is the fallback if edge cases pile up |
| Networking | `URLSession` with conditional requests | Background refresh scheduler with jitter |
| Notifications | `UserNotifications` framework | Actions per notification category |
| Hotkeys | KeyboardShortcuts package (MIT, sindresorhus) | User-recordable shortcuts |
| Launch at login | `SMAppService` |  |
| Focus state | `INFocusStatusCenter` | Needs Focus status permission |
| Screen sharing | Panel `sharingType = .none` plus detection of active capture | See Risks: not reliable on every macOS version |
| Build | Swift Package Manager or Xcode project; `xcodebuild` from the command line | Claude Code can build and run tests in the terminal |
| Licence | MIT |  |

### Project structure

```
NotchFeed/
  App/            app entry, AppDelegate, accessory mode, launch at login
  Core/
    Models/       Feed, Item, Folder, Keyword, Settings (SwiftData)
    Fetching/     Scheduler, FeedFetcher, conditional requests, back-off
    Parsing/      RSSParser, AtomParser, DateParser, FeedDiscovery
    Rules/        PriorityEngine (feed priority + keywords -> route)
    Alerts/       NotificationService, batching, rate limiter
  UI/
    Ticker/       TickerPanel, scroll / fade / static views
    Notch/        NotchPanel, geometry, idle ears
    MenuBar/      MenuBarExtra content
    Preview/      hover popover
    Settings/     settings window tabs
  Services/       VisibilityController (screen share, full screen, Focus)
  Tests/          parser fixtures, priority rules, dedupe, scheduler
  CLAUDE.md       build commands, conventions, current version scope
  PRD.md          this document
```

**Engineering rules for Claude Code**

- Develop in a public GitHub repository from V0.1. Work one version at a time; each version ends with a tagged release (`v0.1.0` etc.) and a CHANGELOG entry.
- Reference FR and NFR IDs in commit messages and issues.
- Parser and priority rules get unit tests with real-world fixture feeds, including broken ones.
- No new third-party dependency without a note in the PR explaining why.

## Versioning and release plan

V1.0 is reached in five pre-releases, each usable on its own; versions follow Semantic Versioning (MAJOR.MINOR.PATCH) with a git tag and CHANGELOG entry per release. Pre-1.0 versions may change settings and data formats; from V1.0 on, data migrations are required.

| Version | Theme | Scope (requirement IDs) | Done when |
| --- | --- | --- | --- |
| V0.1 | Walking skeleton | FR-1.1, 1.2, 1.8, 1.9 (click), 4.1 (feed URL), 4.6, 5.1, 5.2 (basic), 8.1, 8.2, 8.5, 9.1 (General, Feeds), 9.2 | Add 10 feeds, see headlines scroll in a pinned top bar, click opens browser, survives restart |
| V0.2 | Ticker UX | FR-1.3, 1.4, 1.5, 1.6, 1.7, 1.11, 7.4, 9.4 | Switch between scroll, fade, slide and static; an unpinned bar appears on new items and hides again; a zoomed window's title bar under the bar can be dragged after a pass of the pointer; idle CPU within NFR-1 |
| V0.3 | Feeds, rules and alerts | FR-1.9 (menu), 1.10, 3.1 to 3.5, 4.1 (discovery), 4.2, 4.3, 4.4, 4.7, 4.8, 5.2 (snooze), 6.1, 7.1 to 7.3, 8.3, 8.4 | Import an OPML with 100+ feeds; keyword match triggers one native notification; 20 new items give at most one batch alert; ticker hides during a Zoom share |
| V0.4 | Notch panel | FR-2.1 to 2.5 | Hover notch shows latest items; idle ears show unread count; external display uses top-centre fallback |
| V0.5 | Polish and presets | FR-2.6, 4.5, 4.9, 9.3; all NFRs measured | One-click switch between presets; NFR-1 to NFR-6 verified and logged |
| V1.0 | Stable | Bug fixes, data migration framework, README with build-from-source steps and screenshots; no signing, local builds only | Used daily for two weeks without crashes or lost read state |
| V1.1 | Custom drop-in | FR-3.6: notch drop-in with image, summary, keyboard actions; choice between native and custom alerts | Drop-in appears from the notch on alert items and respects rate limits and Focus |
| V2.0 | Platform decision | Decide on porting (see Backlog: Cross-platform port) based on V1 use | Go or no-go recorded with reasons |

## Backlog

These items are worth considering but are not planned in any version yet. An item moves into a version only by giving it FR IDs and adding it to the release plan.

| ID | Item | Why consider it | Notes |
| --- | --- | --- | --- |
| BL-01 | Cross-platform port | Use on Windows and Linux | Tauri preferred; core logic would be rewritten in Rust or shared via a spec |
| BL-02 | Sync with FreshRSS, Miniflux or Feedbin | Read state shared with phone or other readers | Conflicts with "only reader" today; revisit if a phone reader is added |
| BL-03 | iCloud sync between Macs | Same feeds and read state on two Macs | CloudKit with SwiftData |
| BL-04 | iOS companion app | Reading on the go | Large scope; depends on BL-03 |
| BL-05 | Story clustering | Same news from 10 feeds shown once | Title similarity; could use on-device Apple Intelligence |
| BL-06 | AI summaries in hover preview | Faster triage | On-device only, to keep NFR-7 |
| BL-07 | JSON Feed support | Some blogs publish only JSON Feed | Small; could move into V0.5 |
| BL-08 | YouTube and Reddit sources | Common non-RSS sources | Both expose RSS URLs; mostly feed discovery work |
| BL-09 | Podcast and enclosure handling | Show episodes, open in Podcasts | Out of the headline focus |
| BL-10 | Reader view with full-text extraction | Read without the browser | Was a V1 non-goal |
| BL-11 | Read-later integrations | Send to Readwise Reader, Instapaper, Raindrop | Via share extension or API keys |
| BL-12 | Shortcuts and AppleScript actions, URL scheme | Automation, e.g. switch preset from a Focus mode | App Intents framework |
| BL-13 | WidgetKit desktop widget | For users who do want a classic widget | Cheap once the data layer exists |
| BL-14 | Multiple tickers | E.g. news at top, blogs at bottom, or one per display | Each with its own filter |
| BL-15 | Colour or label per feed or folder | Scan the ticker faster |  |
| BL-16 | Advanced filter rules | Regex, author, category, "title contains X and feed is Y" | Extends FR-4.4 and 4.5 |
| BL-17 | Alert sound per feed or keyword | Hear what kind of alert came in |  |
| BL-18 | Auto-update via Sparkle | Updates without rebuilding | Needs signing, which V1 does not include |
| BL-19 | Mac App Store release | Easier install for others | Sandbox limits on window levels and screen-share detection need checking |
| BL-20 | Reading statistics | Which feeds are read or ignored, to prune feeds | Local only |
| BL-21 | Pinned sources in the notch panel | Quick access to favourite sites, inspired by NotchNest bookmarks |  |
| BL-22 | Liquid Glass styling option | Match macOS 26 look | Opt-in theme |

## Risks, decisions and acceptance

### Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| macOS cannot reserve screen space for the bar | Bar covers window title bars and tabs | Bottom placement, translucency, unpinned modes and mouse-dodge (FR-1.5, 1.6, 1.11) |
| Screen-share hiding is unreliable: newer macOS capture APIs may ignore `sharingType = .none` | Headlines visible in a meeting | Also detect known call and capture apps and hide; manual hide hotkey (FR-7.4); test on macOS 14, 15 and 26 |
| Notch panel clashes with other notch apps (NotchNest, Boring Notch) | Overlapping panels, odd hover behaviour | Setting to disable the notch surface; document the conflict |
| Malformed feeds and odd date formats | Missing or misordered items | Lenient parser, fixture tests from real feeds, FeedKit fallback |
| Many feeds fetched at once | CPU and network spikes, rate limiting by sites | Jittered schedule, concurrency limit, conditional requests (FR-8) |
| Continuous scrolling costs energy | Battery drain | Static and fade styles; pause scroll when idle or on battery (setting) |

### Decisions

| Question | Decision |
| --- | --- |
| App name | NotchFeed |
| Default ticker position | Top, under the menu bar |
| Over full-screen apps | Only the notch panel shows; the ticker hides by default |
| Retention default | 30 days, configurable |
| Repository | Public on GitHub from V0.1 |
| Signing and distribution | Build locally only; no Apple Developer account |

### Acceptance for V1.0

- [ ] All FRs scheduled for V0.1 to V0.5 are implemented and checked off in the release plan
- [ ] NFR-1 to NFR-6 measured on a MacBook with notch and recorded in the repo
- [ ] Unit tests pass for parsing, deduplication, priority routing, batching and rate limiting
- [ ] OPML round trip (import, then export) keeps all feeds and folders
- [ ] Two weeks of daily use without a crash or lost read state
- [ ] README with install and build steps, screenshots, MIT licence file
