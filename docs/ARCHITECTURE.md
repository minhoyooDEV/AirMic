# Architecture

AirMic is a single-process Cocoa app with no runtime packages or installed services.

```text
AirPods mute event → AVAudioApplication handler → MuteController.apply
Window/menu toggle ────────────────────────────→ MuteController.apply
                                                     ↓
                                   current default input's hardware mute
                                                     ↓
                                   read back → menu/status window
```

## Responsibilities

| Component | Responsibility |
| --- | --- |
| Core Audio helpers | Resolve the default input, device UID/name, and writable master input mute property |
| `MuteController` | Save original mute values, apply/read back changes, and retry restoration |
| `AirMicDelegate` | Request permission, own input I/O/event registration, and coordinate window/menu lifecycle |
| `StatusModel` / `StatusView` | Present microphone state with SwiftUI and forward actions to the delegate |
| CLI entry point | Read-only diagnostics, explicit hardware test, help/version without a GUI |

Production behavior lives in Swift files under `Source/`. `AudioDevices` provides a small injectable boundary for deterministic mute/restoration tests. It does not add a runtime dependency. `StatusWindow` hosts the SwiftUI view and coordinates native close/reopen behavior.

Interface strings use stable keys through `Source/Localization.swift` and native `NSBundle` resource lookup. `Resources/en.lproj` is the development language, with Korean, Simplified Chinese, Japanese, and Spanish in their `.lproj` folders. The build copies language resources before signing. The SwiftUI status window uses wrapping text and a vertical layout. A native NSVisualEffectView behind-window backdrop supplies actual desktop blur beneath a light adaptive tint and broad radial color washes. SwiftUI draws fine edge highlights and layered controls. The icon uses SwiftUI Material, with a native fallback for older SDKs. Reduced transparency removes desktop bleed-through; reduced motion disables state animation. See [localization](LOCALIZATION.md) for the resource and test contract.

While the status window is visible, the app uses regular activation so it appears in the Dock and app switcher. Closing the window restores accessory activation; the menu bar and audio lifecycle continue. Reopening shows the existing window. Window, app-menu, and status-menu quit actions share the normal termination/restoration path.

## Input and event lifecycle

After microphone permission, the app resolves the public macOS 14 `AVAudioApplication` API, sets up its mute-state handler, and starts an input-only AUHAL unit on the default input. Output I/O is disabled. The callback returns without rendering or reading input buffers.

The public mute notification prompts a main-thread refresh. A 0.5-second UI refresh also checks current mute state and default-device changes. On device change, active input I/O is stopped and recreated; the new device's existing mute state is used. A callback count includes state synchronization and must not be treated as a physical button-press count.

The handler applies the requested mute value, not a blind toggle. Menu/window changes temporarily remove the handler while synchronizing app mute state. Stopping listening unregisters the handler and disposes input I/O; it does not itself restore the microphone. Normal quit performs restoration.

## State restoration

Before the first change to a device, the controller stores its UID and original mute value in `NSUserDefaults` under `OriginalMuteStates`. Access to mutation/restoration is synchronized. It verifies a write by reading the property back. If application fails, it attempts to roll back to the immediately preceding value.

Normal quit walks connected devices and restores saved values. Successful entries are removed; disconnected devices remain saved for a future launch/quit. Connected-device restoration failures produce an alert. Disconnected entries are retained without that alert. There is no guarantee of restoration after a crash or force quit, and quit may overwrite a mute change made by another app since AirMic started.

## SDK compatibility

The runtime requires macOS 14+. Only `AudioApplicationBridge.h` uses a narrow Objective-C protocol and dynamic class/symbol resolution; these let older Command Line Tools compile against the public API. The compiler deployment target is 11.0 to support that SDK; `LSMinimumSystemVersion` is 14.0. This does not claim support for running the app on macOS 11–13.

References: [Apple mute-state handler](https://developer.apple.com/documentation/avfaudio/avaudioapplication/setinputmutestatechangehandler(_:)), [WWDC23 audio session](https://developer.apple.com/videos/play/wwdc2023/10233/).
