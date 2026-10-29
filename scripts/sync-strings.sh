#!/bin/sh
# Merges the strings the last Debug build extracted from the app's sources into the String Catalog.
# Xcode does this when building in the IDE; command-line builds only write the .stringsdata files.
# Run after a build: scripts/sync-strings.sh
set -eu
cd "$(dirname "$0")/.."
find build/Build/Intermediates.noindex/NotchFeed.build/Debug/NotchFeed.build -name '*.stringsdata' -print0 \
  | xargs -0 -I{} printf -- '--stringsdata\0%s\0' {} \
  | xargs -0 xcrun xcstringstool sync Resources/Localizable.xcstrings
echo "Synced Resources/Localizable.xcstrings"
