#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${DEVELOPER_DIR:-}" && -d /Library/Developer/CommandLineTools ]]; then
  export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

# A separate test bundle resolves the same resources as the real app.
# Its entry point never installs the app delegate or starts audio I/O.
test_app=build/LocalizationChecks.app
rm -rf "$test_app"
mkdir -p "$test_app/Contents/MacOS"
cp build/AirMic.app/Contents/Info.plist "$test_app/Contents/Info.plist"
cp -R build/AirMic.app/Contents/Resources "$test_app/Contents/Resources"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier local.airmic.localization-checks' "$test_app/Contents/Info.plist"
xcrun swiftc -parse-as-library -D AIRMIC_TESTING -target "$(uname -m)-apple-macosx11.0" \
  -module-cache-path build/ModuleCache -import-objc-header Source/AudioApplicationBridge.h \
  -framework Cocoa -framework AVFoundation -framework CoreAudio -framework AudioToolbox -framework QuartzCore \
  Source/*.swift Tests/*.swift -o "$test_app/Contents/MacOS/AirMic"
codesign --force --sign - "$test_app"

check_language() {
  "$test_app/Contents/MacOS/AirMic" -AppleLanguages "$1" -ExpectedLanguage "$2" -SourceDirectory "$PWD/Source"
}
check_language '(en)' en
check_language '(ko)' ko
check_language '(ko-KR)' ko
check_language '(fr)' en
check_language '(fr, ko)' ko

check_language '(zh-Hans)' zh-Hans
check_language '(zh-CN)' zh-Hans
check_language '(ja)' ja
check_language '(es)' es
check_language '(es-MX)' es
