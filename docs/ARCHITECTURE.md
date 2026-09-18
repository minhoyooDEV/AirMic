# Architecture

AirMic is a single-process Cocoa app with no runtime packages or installed services.

```text
AirPods mute event → AVAudioApplication handler → Controller.apply
Window/menu toggle ────────────────────────────→ Controller.apply
                                                     ↓
                                   current default input's hardware mute
                                                     ↓
                                   read back → menu/status window
```

## Responsibilities

| Component | Responsibility |
| --- | --- |
| Core Audio helpers | Resolve the default input, device UID/name, and writable master input mute property |
| `Controller` | Save original mute values, apply/read back changes, and retry restoration |
| `App` | Request permission, own input I/O and event registration, render the window/menu |
| CLI entry point | Read-only diagnostics, explicit hardware test, help/version without a GUI |

All implementation lives in `Source/main.m`. Prefer separating a component when behavior or tests justify it, rather than introducing a framework for this small app.

## Input and event lifecycle

After microphone permission, the app resolves the public macOS 14 `AVAudioApplication` API, sets up its mute-state handler, and starts an input-only AUHAL unit on the default input. Output I/O is disabled. The callback returns without rendering or reading input buffers.

The public mute notification prompts a main-thread refresh. A 0.5-second UI refresh also checks current mute state and default-device changes. On device change, active input I/O is stopped and recreated; the new device's existing mute state is used. A callback count includes state synchronization and must not be treated as a physical button-press count.

The handler applies the requested mute value, not a blind toggle. Menu/window changes temporarily remove the handler while synchronizing app mute state. Stopping listening unregisters the handler and disposes input I/O; it does not itself restore the microphone. Normal quit performs restoration.

## State restoration

Before the first change to a device, the controller stores its UID and original mute value in `NSUserDefaults` under `OriginalMuteStates`. Access to mutation/restoration is synchronized. It verifies a write by reading the property back. If application fails, it attempts to roll back to the immediately preceding value.

Normal quit walks connected devices and restores saved values. Successful entries are removed; disconnected devices remain saved for a future launch/quit. Connected-device restoration failures produce an alert. Disconnected entries are retained without that alert. There is no guarantee of restoration after a crash or force quit, and quit may overwrite a mute change made by another app since AirMic started.

## SDK compatibility

The runtime requires macOS 14+. A narrow Objective-C protocol and dynamic class/symbol resolution let older Command Line Tools compile against the public API. The compiler deployment target is 11.0 to support that SDK; `LSMinimumSystemVersion` is 14.0. This does not claim support for running the app on macOS 11–13.

References: [Apple mute-state handler](https://developer.apple.com/documentation/avfaudio/avaudioapplication/setinputmutestatechangehandler(_:)), [WWDC23 audio session](https://developer.apple.com/videos/play/wwdc2023/10233/).
