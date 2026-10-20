#!/bin/zsh
# Builds build/UniveGame-<version>.dmg with the UniveGame drag-to-Applications window.
# Usage (from anywhere): design/dmg/make-dmg.sh [version]
# Needs: create-dmg (brew install create-dmg) and build/UniveGame.app (scripts/bundle.sh release).
set -euo pipefail

ROOT="${0:A:h:h:h}"
HERE="${0:A:h}"
APP="$ROOT/build/UniveGame.app"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
OUT="$ROOT/build/UniveGame-$VERSION.dmg"

[[ -d "$APP" ]] || { echo "Missing $APP. Run scripts/bundle.sh release first." >&2; exit 1; }
rm -f "$OUT"

# The design is 660×400 pt. macOS 26+ Finder always shows its toolbar (≈68 pt incl. title bar) and the
# window size includes it, so the window is 468 pt tall; the background is 440 pt so older systems,
# which hide the toolbar, see plain background below the design. Icon centres match the slots.
# The .tiff carries both 1× and 2× backgrounds so the window is sharp on Retina displays.
create-dmg \
  --volname "UniveGame" \
  --volicon "$ROOT/design/simge/AppIcon.icns" \
  --background "$HERE/dmg-background.tiff" \
  --window-pos 200 120 \
  --window-size 660 468 \
  --icon-size 128 \
  --text-size 13 \
  --icon "UniveGame.app" 180 200 \
  --hide-extension "UniveGame.app" \
  --app-drop-link 480 200 \
  --no-internet-enable \
  "$OUT" "$APP"

echo "$OUT"
