#!/bin/bash
# Builds a distributable BrewManager.dmg.
#
# The disk image contains the app bundle plus a symlink to /Applications so the
# familiar drag-to-install gesture works.
#
# Usage: ./Scripts/build-dmg.sh [configuration]
#        ./Scripts/build-dmg.sh --skip-build   (package the existing bundle as-is)

set -euo pipefail

CONFIGURATION="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/build/BrewManager.app"
BUILD_DIR="$ROOT/build"
STAGING_DIR="$BUILD_DIR/dmg-staging"
VOLUME_NAME="Brew Manager"

cd "$ROOT"

# Rebuilding would discard a Developer ID signature applied by Scripts/notarize.sh,
# so that script packages the already-signed bundle instead.
if [ "$CONFIGURATION" = "--skip-build" ]; then
    echo "==> Skipping build; packaging the existing bundle"
else
    "$ROOT/Scripts/build-app.sh" "$CONFIGURATION"
fi

if [ ! -d "$APP_DIR" ]; then
    echo "error: $APP_DIR was not produced" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist" 2>/dev/null || echo '1.0.0')"
DMG_PATH="$BUILD_DIR/BrewManager-$VERSION.dmg"

echo "==> Staging disk image contents"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# ditto preserves the bundle's signature and extended attributes; cp -R does not.
ditto "$APP_DIR" "$STAGING_DIR/BrewManager.app"
ln -s /Applications "$STAGING_DIR/Applications"

# A short note so a first-time user is not surprised by Gatekeeper.
cat > "$STAGING_DIR/README.txt" <<'NOTE'
Brew Manager
============

To install:
  1. Drag "BrewManager.app" onto the "Applications" folder shown here.
  2. Eject this disk image.
  3. Open Brew Manager from Applications, Launchpad or Spotlight.

First launch
------------
This build is signed ad-hoc rather than with a paid Apple Developer ID, so
macOS may say the app "cannot be opened because the developer cannot be
verified".

If that happens, either:
  - Right-click (or Control-click) the app and choose "Open", then confirm; or
  - Open System Settings > Privacy & Security and click "Open Anyway".

You only need to do this once.

Requirements
------------
  - macOS 14 (Sonoma) or later
  - Homebrew installed (https://brew.sh)

Brew Manager never reimplements Homebrew. It runs your installed `brew`
executable and shows the real command and its real output for every action.
NOTE

echo "==> Creating $DMG_PATH"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" >/dev/null

rm -rf "$STAGING_DIR"

echo "==> Verifying disk image"
hdiutil verify "$DMG_PATH" >/dev/null

SIZE="$(du -h "$DMG_PATH" | cut -f1 | tr -d ' ')"

echo "==> Done: $DMG_PATH ($SIZE)"
echo "    Install with: open \"$DMG_PATH\""
