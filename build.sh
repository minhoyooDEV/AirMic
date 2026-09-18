#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

# Prefer standalone tools; honor an explicitly selected Xcode toolchain.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Library/Developer/CommandLineTools ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

app=build/AirMic.app
mkdir -p "$app/Contents/MacOS"
# Replace bundled localizations so a rebuild cannot retain a removed language.
rm -rf "$app/Contents/Resources"
mkdir -p "$app/Contents/Resources"
cp -R Resources/. "$app/Contents/Resources/"
for strings in "$app"/Contents/Resources/*.lproj/*.strings; do
  plutil -lint "$strings"
done
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter \
  -mmacosx-version-min=11.0 \
  -framework Cocoa -framework AVFoundation -framework CoreAudio -framework AudioToolbox \
  Source/main.m -o "$app/Contents/MacOS/AirMic"
cp Source/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built $app (requires macOS 14 or later)"
