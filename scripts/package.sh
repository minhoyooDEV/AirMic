#!/bin/bash
# Create an ad-hoc-signed universal Mac installer. Publishing is a separate step.
set -euo pipefail
cd "$(dirname "$0")/.."
AIRMIC_UNIVERSAL=1 bash build.sh

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Source/Info.plist)"
architecture=universal
stage="$(mktemp -d "${TMPDIR:-/tmp}/airmic-package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
ditto build/AirMic.app "$stage/AirMic.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/Read Me.txt" <<EOF
AirMic $version — $architecture — macOS 14+

1. Quit any running copy of AirMic using its Quit menu (restores microphone state).
2. Drag AirMic.app to Applications, then open it.
3. Allow microphone access and connect your AirPods.
4. Use the large mute button or your configured AirPods mute gesture.

Closing the window keeps AirMic in the menu bar. Open the app again to show
the window. Choose Quit AirMic or press Command-Q while its window is active
to quit and attempt to restore the original microphone state.

English, Korean, Simplified Chinese, Japanese, and Spanish follow macOS language
preferences. The app does not record
or transmit audio. It controls the current default input, not every microphone.
This local build is ad-hoc signed, not Developer ID signed or notarized.
For first-launch approval, follow Apple's guidance for apps you trust:
https://support.apple.com/102445

한국어
1. 실행 중인 AirMic은 메뉴의 종료로 닫아 마이크 상태를 복원하세요.
2. AirMic.app을 Applications에 드래그하고 실행하세요.
3. 마이크 접근을 허용하고 AirPods를 연결하세요.
4. 큰 마이크 버튼이나 AirPods의 음소거 제스처로 전환하세요.

창을 닫아도 메뉴 막대에서 실행됩니다. 앱을 다시 열면 창이 나타납니다.
완전히 종료하려면 AirMic 종료 또는 활성 창에서 Command-Q를 사용하세요.
한국어·중국어 간체·일본어·스페인어·영어는 macOS 언어 설정을 따릅니다.
이 빌드는 로컬 임시 서명이며
Apple의 Developer ID 서명·공증을 받은 배포판은 아닙니다.
최초 실행 승인은 위 Apple 공식 안내를 참고하세요.
EOF

mkdir -p build/packages
image="build/packages/AirMic-$version-$architecture.dmg"
hdiutil create -quiet -ov -format UDZO -volname AirMic -srcfolder "$stage" "$image"
hdiutil verify "$image"
(cd build/packages && shasum -a 256 "$(basename "$image")" > "$(basename "$image").sha256")
echo "Created $image"
