#!/usr/bin/env bash
#
# Signs BrewManager with a Developer ID certificate, notarises it with Apple,
# and staples the ticket so the DMG opens without any Gatekeeper warning.
#
# This is the one step that cannot be done without your own Apple credentials,
# so nothing here is baked into the normal build. Run it only when you want to
# distribute the app to other people; the ad-hoc signed build produced by
# Scripts/build-dmg.sh is fine on your own machine.
#
# Prerequisites
#   1. A paid Apple Developer account ($99/yr).
#   2. A "Developer ID Application" certificate in your login keychain.
#      Check with:  security find-identity -v -p codesigning
#   3. A notarytool keychain profile, created once with:
#
#        xcrun notarytool store-credentials "BrewManagerNotary" \
#          --apple-id "you@example.com" \
#          --team-id "ABCDE12345" \
#          --password "app-specific-password"
#
#      (Generate the app-specific password at https://appleid.apple.com.)
#
# Usage
#   DEVELOPER_ID="Developer ID Application: Your Name (ABCDE12345)" \
#     ./Scripts/notarize.sh
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_PATH="$BUILD_DIR/BrewManager.app"
ENTITLEMENTS="$BUILD_DIR/BrewManager.entitlements"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-BrewManagerNotary}"

fail() {
    echo "error: $*" >&2
    exit 1
}

[[ -n "${DEVELOPER_ID:-}" ]] || fail "set DEVELOPER_ID to your 'Developer ID Application: ...' identity"

echo "==> Building a fresh release bundle"
"$ROOT_DIR/Scripts/build-app.sh" release

[[ -d "$APP_PATH" ]] || fail "missing $APP_PATH"

# BrewManager runs `brew`, which in turn runs Ruby and downloads files, so the
# hardened runtime needs the JIT and unsigned-memory exceptions. The app is not
# sandboxed: sandboxing would block it from executing Homebrew at all.
echo "==> Writing entitlements"
cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Signing with Developer ID (hardened runtime)"
codesign --force --deep --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID" \
    "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Submitting the app for notarisation"
ZIP_PATH="$BUILD_DIR/BrewManager-notarize.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

echo "==> Stapling the ticket to the app"
xcrun stapler staple "$APP_PATH"
rm -f "$ZIP_PATH"

echo "==> Packaging the notarised app into a DMG"
"$ROOT_DIR/Scripts/build-dmg.sh" --skip-build

DMG_PATH="$(ls -t "$BUILD_DIR"/BrewManager-*.dmg | head -n 1)"

echo "==> Signing and notarising the DMG itself"
codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type execute --verbose=2 "$APP_PATH"

echo "==> Done: $DMG_PATH"
echo "    This disk image installs with no Gatekeeper warning on any Mac."
