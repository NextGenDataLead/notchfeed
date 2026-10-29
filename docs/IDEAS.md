# Ideas

Ideas that came up while building a version but belong to a later one. An idea only gets built after it has been given FR IDs in the PRD.

- **Follow permanent redirects (301/308) by updating the stored feed URL.** V0.1 follows them on every fetch. Fits FR-4.9 feed health (V0.5).
- **Flag feeds that have stopped updating.** A feed whose newest item is older than the retention window shows "Updated just now" with zero headlines, which looks broken. Show "No new items since <date>" instead. Fits FR-4.9 feed health (V0.5).
