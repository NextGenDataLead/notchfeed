# NotchFeed

Native, open-source macOS app (MIT) that keeps the latest RSS/Atom headlines in view through a ticker bar, a notch panel, a menu bar item and alerts. Built for one user first: a MacBook with a notch, 50 to 200 feeds, no other RSS reader.

**Source of truth: `PRD.md`.** Requirement IDs (FR-x.y, NFR-x, BL-xx) come from there. If this file and the PRD disagree, the PRD wins; flag the conflict to the user.

## Current version

**Working on: V0.2 — Ticker UX** (V0.1 tagged 2026-10-30; manual checks 18 and 19 still to run)

Scope (from PRD release plan): FR-1.3, 1.4, 1.5, 1.6, 1.7, 1.11, 7.4, 9.4. Settings for these go in a new Ticker tab (FR-9.1).

Done when: the user can switch between scroll, fade, slide and static; an unpinned bar appears on new items and hides again; a zoomed window's title bar under the bar can be dragged after a pass of the pointer; idle CPU is within NFR-1.

Not started yet: begin with a plan-mode round (FRs, files, order) and wait for the go-ahead. KeyboardShortcuts (approved dependency) arrives with FR-9.4.

Update this section when a version is tagged and the next one starts.

## Workflow rules

- Work on **one version at a time**. Do not build features from later versions, even small ones. Note good ideas in `docs/IDEAS.md` instead.
- Start each version in plan mode: list the FRs, the files you will touch and the order. Wait for the user's go-ahead.
- Small commits. Reference requirement IDs in every commit message, e.g. `feat(ticker): pinned top bar (FR-1.1, FR-1.2)`. Use Conventional Commits.
- When the PRD is ambiguous, ask. Record the answer in `docs/DECISIONS.md` (date, question, decision).
- Finishing a version: all tests pass, `CHANGELOG.md` updated, `docs/TESTING.md` checklist for that version written, then tag `vX.Y.0` after the user confirms the manual checks.
- You cannot see the screen. For anything visual (panel position, animation, notch fit), describe what the user should check and ask them to confirm.
- No new third-party dependency without asking first and noting why in the commit. Approved: KeyboardShortcuts (sindresorhus, MIT). FeedKit only if the own parser proves insufficient.
- No code signing, notarisation or App Store setup. Local builds only.

## Tech stack

- Swift 6 with strict concurrency, SwiftUI views hosted in AppKit `NSPanel` windows.
- Minimum macOS 14 Sonoma; the user runs macOS 26.
- Xcode project generated with **XcodeGen** from `project.yml`, so the project stays a readable text file. Never hand-edit `.xcodeproj`; it is not committed.
- Accessory app (`LSUIElement = YES`): no Dock icon; UI lives in panels and a `MenuBarExtra`.
- Storage: SwiftData. Networking: `URLSession` with ETag / If-Modified-Since. Parsing: own parser on `XMLParser`.
- Launch at login: `SMAppService`. Notifications (from V0.3): `UserNotifications`.

## Commands

```bash
brew install xcodegen                     # once
xcodegen generate                         # after changing project.yml or adding files
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -configuration Debug -derivedDataPath build build
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -derivedDataPath build test -destination 'platform=macOS'
open build/Build/Products/Debug/NotchFeed.app
pkill -x NotchFeed                        # stop the running app before rebuilding
scripts/sync-strings.sh                   # after a build: add new UI strings to Localizable.xcstrings
```

Run the build and the tests after every meaningful change. Fix warnings, not just errors.

## Project structure

```
App/            entry point, AppDelegate, accessory mode, launch at login
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
Tests/
  Fixtures/     real-world feeds, including broken ones
docs/           DECISIONS.md, TESTING.md, IDEAS.md
```

Only create folders when a version needs them.

## Code conventions

- UI types are `@MainActor`. Fetching and parsing run off the main actor (actors or `Sendable` services).
- No force unwraps or `try!` outside tests.
- Panels: non-activating `NSPanel`, level above normal windows, `collectionBehavior` `.canJoinAllSpaces`; the ticker hides over full-screen apps by default (only the notch panel shows there).
- Notch geometry from `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`; always handle displays without a notch.
- Every user-facing string goes in the String Catalog (`Localizable.xcstrings`).
- Every setting has a default that matches the PRD (ticker at top, retention 30 days, refresh 15 minutes, max 6 parallel fetches).

## Testing

- Unit tests for parsing (RSS 2.0, RSS 1.0, Atom, malformed XML, odd date formats), deduplication, retention and, from V0.3, priority routing, batching and rate limiting.
- Store fixture feeds in `Tests/Fixtures/`; never hit the network in tests.
- Performance targets are in the PRD (NFR-1 to NFR-6). From V0.5, measure them and record results in `docs/TESTING.md`.

## Repository

- Public GitHub repository from V0.1, MIT licence.
- Keep `README.md` current: what the app does, how to build from source, screenshots once there is UI.