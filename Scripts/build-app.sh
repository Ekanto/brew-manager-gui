#!/bin/bash
# Packages BrewManager as a real macOS .app bundle.
#
# A bare SwiftPM executable has no Info.plist, so macOS treats it as a
# background-only process whose windows cannot become key (no keyboard input).
# Building a proper bundle is the correct fix for a macOS GUI app.

set -euo pipefail

CONFIGURATION="${1:-release}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/build/BrewManager.app"
ICON_SRC="$ROOT/Resources/AppIcon.icns"

cd "$ROOT"

echo "==> Building ($CONFIGURATION)"
swift build -c "$CONFIGURATION"

BIN="$(swift build -c "$CONFIGURATION" --show-bin-path)/BrewManager"
if [ ! -x "$BIN" ]; then
    echo "error: executable not found at $BIN" >&2
    exit 1
fi

if [ ! -f "$ICON_SRC" ]; then
    echo "==> Generating app icon"
    swift "$ROOT/Scripts/make-icon.swift" "$ROOT/Resources"
fi

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/BrewManager"

if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>BrewManager</string>
    <key>CFBundleIdentifier</key>
    <string>com.brewmanager.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>BrewManager</string>
    <key>CFBundleDisplayName</key>
    <string>Brew Manager</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$APP_DIR" >/dev/null 2>&1 || \
    echo "warning: ad-hoc codesign failed; the app will still run locally"

echo "==> Done: $APP_DIR"
echo "    Launch with: open \"$APP_DIR\""
