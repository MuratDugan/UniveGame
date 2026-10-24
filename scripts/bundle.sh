#!/bin/zsh
# Builds UniveGame and wraps it in build/UniveGame.app.
# Usage: scripts/bundle.sh [debug|release]
# Version: the VERSION file (CFBundleShortVersionString); build number: git commit count, else a timestamp.
# Signing: ad-hoc by default (runs on this Mac only). Set SIGN_IDENTITY to a "Developer ID Application: …"
# identity for a distributable build (hardened runtime + secure timestamp, ready for notarization).
set -euo pipefail

CONFIG="${1:-release}"
ROOT="${0:A:h:h}"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD="$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d%H%M)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# SwiftUI's macros ship with Xcode, not with the Command Line Tools.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)"

APP="$ROOT/build/UniveGame.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/UniveGame" "$APP/Contents/MacOS/UniveGame"
cp -R "$BIN/UniveGame_UniveGame.bundle" "$APP/Contents/Resources/"
for lang in en tr; do mkdir -p "$APP/Contents/Resources/$lang.lproj"; done  # lets macOS localize system menus
# The microphone prompt's text, in the user's language (games ask for it for voice chat).
printf '"NSMicrophoneUsageDescription" = "Games you start from UniveGame can use the microphone for voice chat.";\n' \
  > "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
printf '"NSMicrophoneUsageDescription" = "UniveGame’den başlattığın oyunlar sesli sohbet için mikrofonu kullanabilir.";\n' \
  > "$APP/Contents/Resources/tr.lproj/InfoPlist.strings"

# App icon: packaging/AppIcon.icns, or built from packaging/AppIcon-1024.png when only the PNG exists.
ICON_KEY=""
if [[ ! -f packaging/AppIcon.icns && -f packaging/AppIcon-1024.png ]]; then
  SET="$(mktemp -d)/AppIcon.iconset"; mkdir -p "$SET"
  for s in 16 32 128 256 512; do
    sips -z $s $s packaging/AppIcon-1024.png --out "$SET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) packaging/AppIcon-1024.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$SET" -o packaging/AppIcon.icns
fi
if [[ -f packaging/AppIcon.icns ]]; then
  cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  ICON_KEY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>UniveGame</string>
  <key>CFBundleDisplayName</key><string>UniveGame</string>
  <key>CFBundleIdentifier</key><string>dev.univegame.launcher</string>
  <key>CFBundleExecutable</key><string>UniveGame</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>VERSION_PLACEHOLDER</string>
  <key>CFBundleVersion</key><string>BUILD_PLACEHOLDER</string>
  <key>NSHumanReadableCopyright</key><string>UniveGame. Built on MacadeKit (Apache 2.0).</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>tr</string></array>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>dev.univegame.play</string>
    <key>CFBundleURLSchemes</key><array><string>univegame</string></array>
  </dict></array>
  <key>NSMicrophoneUsageDescription</key><string>Games you start from UniveGame can use the microphone for voice chat.</string>
  ICON_PLACEHOLDER
</dict>
</plist>
PLIST

# Discord Rich Presence needs the public application id of the "UniveGame" app on discord.com/developers.
DISCORD_KEY=""
if [[ -f packaging/discord-client-id ]]; then
  DISCORD_ID="$(tr -dc '0-9' < packaging/discord-client-id)"
  [[ -n "$DISCORD_ID" ]] && DISCORD_KEY="<key>UniveGameDiscordClientID</key><string>$DISCORD_ID</string>"
fi
ICON_KEY="$ICON_KEY$DISCORD_KEY"
/usr/bin/sed -i '' -e "s|ICON_PLACEHOLDER|$ICON_KEY|" -e "s|VERSION_PLACEHOLDER|$VERSION|" -e "s|BUILD_PLACEHOLDER|$BUILD|" \
  "$APP/Contents/Info.plist"

ENTITLEMENTS="$ROOT/packaging/UniveGame.entitlements"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --entitlements "$ENTITLEMENTS" --sign - "$APP" >/dev/null
else
  # Hardened runtime is required for notarization. Its one exception is microphone access, for games' voice chat:
  # Wine runs as separate processes, but macOS asks on UniveGame's behalf. Nothing is loaded into UniveGame itself.
  codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --deep "$APP"
fi
echo "$APP"
