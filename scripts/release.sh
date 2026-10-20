#!/bin/zsh
# Builds a release UniveGame DMG signed with your Developer ID, notarized by Apple and stapled, so it opens
# on any Mac without Gatekeeper warnings.
# Usage: scripts/release.sh            (version from the VERSION file)
#
# One-time setup (needs your Apple Developer account, team T21…):
#   1. Xcode › Settings › Accounts › your team › Manage Certificates › + › "Developer ID Application".
#      (Only the account holder can create it.) It lands in your login keychain.
#   2. An app-specific password from https://account.apple.com (Sign-In and Security › App-Specific Passwords), then:
#        xcrun notarytool store-credentials UniveGame --apple-id <your Apple ID> --team-id <T21…>
#      It asks for the password and keeps it in the keychain; this script only uses the profile name.
# Env: SIGN_IDENTITY (default: the first "Developer ID Application" identity), NOTARY_PROFILE (default UniveGame).
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"
VERSION="$(tr -d '[:space:]' < VERSION)"
NOTARY_PROFILE="${NOTARY_PROFILE:-UniveGame}"
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No \"Developer ID Application\" certificate in the keychain. See step 1 at the top of this script." >&2
  exit 1
fi
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "No notarytool profile \"$NOTARY_PROFILE\". See step 2 at the top of this script." >&2
  exit 1
fi
echo "Signing UniveGame $VERSION with: $SIGN_IDENTITY"

SIGN_IDENTITY="$SIGN_IDENTITY" scripts/bundle.sh release
DMG="$(design/dmg/make-dmg.sh "$VERSION" | tail -1)"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "Submitting to Apple for notarization (usually a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

# What Gatekeeper will say on another Mac.
spctl --assess --type open --context context:primary-signature --verbose "$DMG"
echo "$DMG"
