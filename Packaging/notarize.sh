#!/bin/bash
# Submits a built DMG to Apple's notary service and staples the ticket.
#
# Store credentials once (password is an app-specific password from appleid.apple.com):
#   xcrun notarytool store-credentials copyforllm \
#     --apple-id you@example.com --team-id 38X62GQ8HC --password APP_SPECIFIC_PASSWORD
#
# Then:
#   Packaging/notarize.sh Packaging/build/CopyForLLM-0.1.0.dmg
set -euo pipefail

DMG="${1:?usage: notarize.sh <path-to-dmg>}"
PROFILE="${NOTARY_PROFILE:-copyforllm}"

echo "==> Submitting $DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Verifying Gatekeeper assessment"
spctl -a -t open --context context:primary-signature -v "$DMG"
