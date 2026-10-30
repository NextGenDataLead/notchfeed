# Changelog

All notable changes to this project are documented here. This project follows [Semantic Versioning](https://semver.org) and the [Keep a Changelog](https://keepachangelog.com) format.

## [Unreleased]

## [0.1.0] - 2026-10-30

### Added

- Ticker bar: a thin, non-activating bar on every Space, kept off full-screen apps, under the menu bar or above the Dock, on the display you choose (FR-1.1, FR-1.2).
- Ticker items with favicon, optional feed name, headline and relative age; read items are dimmed (FR-1.8).
- Click a headline to open it in the default browser and mark it read (FR-1.9).
- Add a feed by URL, checked before it's saved. Https is tried first; plain http needs a per-feed opt-in after a warning (FR-4.1).
- Read state, per-feed deduplication by GUID or link, and retention of 30 days by default, configurable (FR-4.6).
- Menu bar icon with optional unread count. The dropdown has the 20 newest items, Refresh Now, Pause Ticker, Settings and Quit (FR-5.1, FR-5.2).
- Own parser for RSS 2.0, RSS 1.0 and Atom that tolerates common broken XML and odd dates (FR-8.1).
- Conditional requests (ETag, If-Modified-Since), 304 handling and 429 Retry-After (FR-8.2).
- At most 6 feed requests in flight; fixed 15-minute refresh (FR-8.5).
- Settings window with General and Feeds tabs (FR-9.1), and Open at login (FR-9.2).
- VoiceOver labels on ticker items; Reduce Motion stops the scroll (NFR-6).
- Project scaffold: XcodeGen `project.yml`, core framework and Swift Testing target with fixture feeds.

### Fixed during testing

- Web pages in HTML5 are recognised as "not a feed" instead of "couldn't be read" (FR-4.1).
- Only one copy of NotchFeed runs at a time; a second copy quits at launch.
- The unread count is a small badge on the icon, so the item still fits beside the notch (FR-5.1).
- The ticker hides over full-screen apps on macOS 26, detected from the window list (FR-1.1).
- A clicked headline dims at once instead of at the end of the scroll loop (FR-1.9).
- Setting changes such as Show feed name apply at once (FR-1.8, FR-9.1).
