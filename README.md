# NotchFeed

NotchFeed is a native, open-source macOS app that keeps the latest headlines from your RSS and Atom feeds in view without opening a reader. It shows them in a ticker bar, a notch panel, a menu bar item and alerts.

It runs entirely on your Mac: there's no account, no tracking and no server. MIT licence.

> **Status:** V0.1 (walking skeleton) is in progress. It covers the pinned ticker bar, the menu bar item, adding feeds by URL, and launch at login.

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

NotchFeed is an accessory app, so it has no Dock icon. Look for the newspaper icon in the menu bar.

## Licence

MIT. See [LICENSE](LICENSE).
