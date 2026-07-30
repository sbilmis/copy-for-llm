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
# `notarytool submit` exits 0 when the *upload* succeeds, even if Apple then
# rejects the archive — so check the reported status before stapling.
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait 2>&1 | tee "$LOG"

if ! grep -q "status: Accepted" "$LOG"; then
    SUBMISSION_ID=$(awk '/^ *id: /{print $2; exit}' "$LOG")
    echo >&2
    echo "!! Notarization failed. Apple's log follows:" >&2
    [[ -n "$SUBMISSION_ID" ]] && \
        xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$PROFILE" >&2
    exit 1
fi

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Verifying Gatekeeper assessment"
spctl -a -t open --context context:primary-signature -v "$DMG"
