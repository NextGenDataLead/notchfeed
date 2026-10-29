# Testing

## Automated

```bash
xcodegen generate
xcodebuild -project NotchFeed.xcodeproj -scheme NotchFeed -derivedDataPath build test -destination 'platform=macOS'
```

Tests never hit the network. Fixture feeds live in `Tests/Fixtures/`.

## Manual checklists

The V0.1 checklist is added at the end of V0.1.
