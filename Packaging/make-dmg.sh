#!/bin/bash
# Builds a Release app, signs it with Developer ID when available, and produces a DMG.
#
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" Packaging/make-dmg.sh
#
# Without DEVELOPER_ID the app is ad-hoc signed — fine for local testing, but
# Gatekeeper will warn on other machines. Notarize with Packaging/notarize.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Copy for LLM"
DERIVED=".build/DerivedData"
STAGING=".build/dmg-staging"
VERSION=$(awk -F'"' '/MARKETING_VERSION:/ {print $2; exit}' project.yml)
VERSION="${VERSION:-0.1.0}"
OUTPUT="Packaging/build/CopyForLLM-${VERSION}.dmg"

echo "==> Generating project"
xcodegen generate

echo "==> Building Release"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    xcodebuild -project CopyForLLM.xcodeproj -scheme CopyForLLM \
        -configuration Release -derivedDataPath "$DERIVED" \
        CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
        OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" build
else
    echo "    (no DEVELOPER_ID set — ad-hoc signing)"
    xcodebuild -project CopyForLLM.xcodeproj -scheme CopyForLLM \
        -configuration Release -derivedDataPath "$DERIVED" build
fi

APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "build product not found at $APP" >&2; exit 1; }

echo "==> Staging"
rm -rf "$STAGING" && mkdir -p "$STAGING" "Packaging/build"
ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating DMG"
rm -f "$OUTPUT"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" \
    -ov -format UDZO "$OUTPUT" >/dev/null
rm -rf "$STAGING"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$OUTPUT"
fi

echo "==> Wrote $OUTPUT"
shasum -a 256 "$OUTPUT"
