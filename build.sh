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
xcrun swiftc -module-cache-path build/ModuleCache scripts/make-icon.swift -o build/make-icon
build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
compile_arch() {
  xcrun swiftc -parse-as-library -O -target "$1-apple-macosx11.0" \
    -module-cache-path build/ModuleCache -import-objc-header Source/AudioApplicationBridge.h \
    -framework Cocoa -framework AVFoundation -framework CoreAudio -framework AudioToolbox -framework QuartzCore \
    Source/*.swift -o "$2"
}
if [[ "${AIRMIC_UNIVERSAL:-0}" == 1 ]]; then
  compile_arch arm64 build/AirMic-arm64
  compile_arch x86_64 build/AirMic-x86_64
  xcrun lipo -create build/AirMic-arm64 build/AirMic-x86_64 -output "$app/Contents/MacOS/AirMic"
  xcrun lipo "$app/Contents/MacOS/AirMic" -verify_arch arm64 x86_64
else
  compile_arch "$(uname -m)" "$app/Contents/MacOS/AirMic"
fi
cp Source/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
echo "Built $app (requires macOS 14 or later)"
