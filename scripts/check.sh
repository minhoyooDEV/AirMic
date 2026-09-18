#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'AirMic checks require macOS.' >&2
  exit 1
fi

python3 scripts/build-site.py --check

bash -n build.sh scripts/check.sh scripts/check-localizations.sh scripts/package.sh
bash build.sh

app=build/AirMic.app
bin="$app/Contents/MacOS/AirMic"
plist="$app/Contents/Info.plist"
/usr/bin/plutil -lint "$plist"
/usr/bin/codesign --verify --strict "$app"

plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
[[ "$(plist_value CFBundleIdentifier)" == local.airmic.app ]]
[[ "$(plist_value LSMinimumSystemVersion)" == 14.0 ]]
[[ "$(plist_value CFBundleExecutable)" == AirMic ]]
[[ "$(plist_value LSUIElement)" == true ]]
[[ -n "$(plist_value NSMicrophoneUsageDescription)" ]]
[[ "$("$bin" --version)" == "AirMic $(plist_value CFBundleShortVersionString)" ]]

help_output="$("$bin" --help)"
[[ "$help_output" == *'Usage: AirMic'* ]]
[[ "$help_output" == *'--self-test'* ]]

# Invalid arguments must exit without launching the GUI or starting audio I/O.
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/airmic-check.XXXXXX")"
trap 'rm -rf "$temp_dir"' EXIT
expect_usage_error() {
  local status=0
  "$bin" "$@" >"$temp_dir/stdout" 2>"$temp_dir/stderr" || status=$?
  [[ "$status" -eq 64 ]]
  [[ ! -s "$temp_dir/stdout" ]]
  [[ -s "$temp_dir/stderr" ]]
}
expect_usage_error --invalid
expect_usage_error --help extra
expect_usage_error --self-test extra

bash scripts/check-localizations.sh

echo "PASS: build, bundle metadata, signature, help/version, invalid arguments ($(uname -m))."
echo 'Hardware tests were not run. See docs/TESTING.md.'
