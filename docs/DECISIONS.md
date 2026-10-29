# Decisions

Answers to open questions and deviations from the PRD or CLAUDE.md. The newest entries are at the bottom.

| Date | Question | Decision |
| --- | --- | --- |
| 2026-10-29 | How is the code split into targets? | The `NotchFeed` app contains `App/` and `UI/`, the `NotchFeedCore` framework contains `Core/`, and `NotchFeedCoreTests` links only the framework, so tests never launch the accessory app. |
| 2026-10-29 | Sandbox and signing? | No App Sandbox. Ad-hoc signature (`CODE_SIGN_IDENTITY = "-"`) because arm64 binaries must be signed to run. No Developer ID or notarisation. |
| 2026-10-29 | FR-1.1: how does the ticker stay off full-screen apps? | The ticker panel uses `.canJoinAllSpaces`, `.stationary` and `.ignoresCycle` without `.fullScreenAuxiliary`, so macOS keeps it off full-screen Spaces. The PRD tech-stack table lists `fullScreenAuxiliary`; CLAUDE.md wins here. The FR-7.2 setting and allow list follow in V0.3. |
| 2026-10-29 | Where are settings stored? | `UserDefaults` through a typed `AppSettings`, not a SwiftData `Settings` model. This is simpler and needs no migrations. It differs from the CLAUDE.md models list; approved by the user. |
| 2026-10-29 | Refresh schedule in V0.1? | Fixed 15 minute interval, plus a fetch at launch and on "Refresh now". All feeds are fetched each cycle with at most 6 requests in parallel. A configurable interval and spreading fetches over it come in V0.2 (FR-8.3). |
| 2026-10-29 | FR-4.6: what does retention measure? | An item's age is `publishedAt`, or `firstSeenAt` when the feed gives no date. Items are purged at launch and every 24 hours. Ingest skips items that are already older than the window, so purged items don't come back. Undated items get their first-seen date, so they are only purged once their feed hasn't listed them for the whole window (`Item.lastSeenAt`); otherwise they would return as new after each purge. |
| 2026-10-29 | FR-1.8: where do favicons come from? | The feed's `<image>` or Atom `<icon>`/`<logo>` first, otherwise `https://<site host>/favicon.ico`. Stored on the feed and refreshed weekly. No third-party favicon service (NFR-7). |
| 2026-10-29 | FR-1.2: how is the display chosen? | Default is the primary display (the one with the menu bar). A specific display is saved by `CGDirectDisplayID` and name. If that display isn't connected, the ticker uses the primary display. |
| 2026-10-29 | Ticker geometry in V0.1? | Fixed height of 24 pt. Top position sits right under `visibleFrame.maxY`, bottom position on `visibleFrame.minY`, above the Dock. Window level `.floating`. |
| 2026-10-29 | Reduce Motion in V0.1? | The ticker doesn't scroll. The static and fade styles arrive in V0.2. |
| 2026-10-29 | Which items does the ticker show in V0.1? | The latest 50 items across all feeds, newest first. Read items stay but are dimmed. |
| 2026-10-29 | FR-5.2: what does "Pause ticker" do? | It stops scrolling and leaves the bar visible. The menu item becomes "Resume ticker". Fetching continues. The paused state isn't kept after a restart. |
| 2026-10-29 | FR-4.6: dedupe scope? | Per feed only. The key is the feed ID plus the GUID, or the link when there's no GUID, or a hash of title and date when there's neither. Merging across feeds is backlog BL-05. |
| 2026-10-29 | LICENSE copyright holder? | NextGenDataLead. |
| 2026-10-29 | FR-9.2: default for launch at login? | Off. The PRD gives no default, and an app shouldn't add itself to Login Items without being asked. The toggle shows the real `SMAppService` status. |
| 2026-10-29 | How are fetch errors stored? | As a short code in `Feed.lastError` (for example `http:404`), turned into a localised message by the app. The Core framework has no user-facing strings. |
| 2026-10-29 | Plain `http://` feeds? | Https only by default, with http allowed per feed. When an `http://` URL is added, the `https://` version is tried first. If that fails, the Feeds tab warns that the connection is unencrypted and can be read or altered, and offers "Allow insecure connection for this feed". Insecure feeds are marked in the list. An https feed that redirects to http is blocked unless the feed allows it. Because ATS can't be changed at runtime, `NSAllowsArbitraryLoads` is on and the scheme policy is enforced in code: every request (feeds, favicons, redirects) goes through one `HTTPClient` that refuses `http://` unless the feed allows it. This is a deliberate exception to the "don't disable ATS" rule. |
