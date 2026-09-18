# AirMic

A tiny macOS menu bar app that lets you mute and unmute your **default input microphone** with your AirPods stem button.

[한국어](README.ko.md)

Built with Objective-C and Apple's system frameworks. No dependencies, audio drivers, background services, accounts, or network requests. The current interface is in Korean.

## Build and run

Requires **macOS 14+**, Apple Command Line Tools or Xcode, compatible AirPods, and a microphone with a writable Core Audio mute control. The stem gesture has been tested on one Apple Silicon Mac with AirPods Pro; other devices and macOS versions are not yet verified.

```sh
# Install Apple's developer tools if needed:
xcode-select --install

# From this repository:
bash build.sh
open build/AirMic.app
```

The script builds for your Mac's architecture and applies a local ad-hoc signature. There is no notarized download. It prefers standalone Command Line Tools when installed; set `DEVELOPER_DIR` to use a particular Xcode installation. Building does not accept Apple's license agreements for you.

## Use

1. Connect your AirPods and select the microphone you want to control as the Mac's default input.
2. Open AirMic and allow microphone access if prompted.
3. Wait for **AirPods 버튼 감지 중** (listening for AirPods controls).
4. Press the stem using your configured mute/unmute gesture. The window and menu bar icon show the microphone's mute state.

You can also toggle mute in the window or menu. Closing the window leaves the app in the menu bar. To stop it, choose **종료 (원래 마이크 상태 복원)**, which attempts to restore the original mute state of microphones changed by AirMic.

## Scope and tradeoffs

- This changes the **device-level mute state of the current default input**, affecting apps that use that microphone. It does not mute every connected microphone or change an app's own mute button.
- Listening uses an input-only Core Audio HAL audio unit and the public `AVAudioApplication` mute handler/notification. The input callback does not read, save, transmit, or play microphone buffers.
- macOS may show its microphone-use indicator. Keeping input I/O active can affect Bluetooth playback quality and battery use.
- Other calling apps may compete for AirPods controls. Do not assume every conferencing app is compatible. Test in your intended app before relying on it.
- AirMic reads back the hardware mute property after changing it. This is not an end-to-end guarantee that another app is silent.
- When the default input changes, AirMic observes the new device's existing mute state; it does **not** carry your previous mute state to that device.
- Force-quitting, crashes, or disconnected devices can prevent restoration. Reconnect the device, launch AirMic, and quit normally to retry. Original device IDs and mute values are stored locally for this purpose.
- No automatic login launch, updater, telemetry, or recording history.

## Development checks

```sh
# Read-only capability/state check:
build/AirMic.app/Contents/MacOS/AirMic --check

# Hardware test: briefly flips mute and restores the original state.
# Avoid running during an active call or recording.
build/AirMic.app/Contents/MacOS/AirMic --self-test
```

`--self-test` exercises real hardware; it is not suitable for unattended CI. Build, signature verification, hardware state restoration, and physical AirPods stem toggling were verified locally.

## Uninstall

Quit from AirMic's menu so it can restore the microphone, then remove the app. To remove saved settings after confirming restoration:

```sh
defaults delete local.airmic.app
```

## Implementation

- `Source/main.m` — menu/window, AirPods events, Core Audio mute control
- `Source/Info.plist` — app identity and microphone permission description
- `build.sh` — compile and locally sign the app

The small Objective-C protocol declaration allows compilation with an older SDK while resolving the **public macOS 14 API** at runtime. The app bundle still requires macOS 14 or later.

References: [Apple mute-handler API](https://developer.apple.com/documentation/avfaudio/avaudioapplication/setinputmutestatechangehandler(_:)), [WWDC23 AirPods audio session](https://developer.apple.com/videos/play/wwdc2023/10233/).

## License

[MIT](LICENSE). AirMic is an independent project, not affiliated with Apple.
