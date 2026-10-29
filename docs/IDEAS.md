# Ideas

Ideas that came up while building a version but belong to a later one. An idea only gets built after it has been given FR IDs in the PRD.

- **Follow permanent redirects (301/308) by updating the stored feed URL.** V0.1 follows them on every fetch. Fits FR-4.9 feed health (V0.5).
- **Stream responses with a byte cap.** V0.1 downloads the whole body and then rejects anything over 10 MB.
