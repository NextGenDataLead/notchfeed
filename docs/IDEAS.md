# Ideas

Ideas that came up while building a version but belong to a later one. An idea only gets built after it has been given FR IDs in the PRD.

- **Follow permanent redirects (301/308) by updating the stored feed URL.** V0.1 follows them on every fetch. Fits FR-4.9 feed health (V0.5).
- **Flag feeds that have stopped updating.** A feed whose newest item is older than the retention window shows "Updated just now" with zero headlines, which looks broken. Show "No new items since <date>" instead. Fits FR-4.9 feed health (V0.5).
- **Keep other windows out from under the bar.** macOS sizes zoomed and filled windows (double-click on the title bar, Window › Fill) to the screen's `visibleFrame`, which only the menu bar and the Dock reduce. An app can't reserve space there. The only route is the Accessibility API: watch other apps' windows and push any window whose top edge lands under the bar down by the bar's height. That needs the Accessibility permission, fights with window managers and apps that place their own windows, and must skip full-screen windows. Raised during V0.1 testing; would need a new FR next to FR-1.6 overlap handling (V0.2).
