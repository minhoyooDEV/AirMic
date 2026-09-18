# Testing

## Automated checks

Run `bash scripts/check.sh`. It builds the app, checks shell syntax and bundle metadata, verifies the ad-hoc signature, and tests version/help/invalid-argument exit behavior. These CLI cases return before creating the application or touching audio hardware.

It also builds a separate Swift test bundle. This checks resource keys, format placeholders, localized permission text, all five supported languages/region-specific language selection, English fallback, and compact SwiftUI fitting sizes/presentation states in both appearances using the production view code. Visual and accessibility interaction checks complement these size checks; they are not pixel-perfect layout tests. The test creates an offscreen AppKit window but never installs the app delegate, uses real microphone devices, requests microphone permission, or starts audio I/O. An active macOS GUI session is needed for the layout checks.

The mute controller is tested with fake devices and an isolated, temporary UserDefaults suite. Cases include idempotent events, first-change snapshots, device switches, write failure/rollback, partial restoration, disconnected retry after relaunch, enumeration failure, and unsupported inputs. No real audio properties are changed.

GitHub Actions runs the same checks on Apple Silicon and Intel macOS runners. The packaging script separately cross-compiles both architectures and verifies the universal executable and DMG. A maintainer verifies and uploads the installer after CI passes. This establishes compilation, CLI/localization behavior, and simulated controller behavior. It does not test Bluetooth, microphone permission, stem events, audio transmission, or restoration on hardware. No coverage percentage is claimed.

## Evidence so far

| Environment | Evidence | Limit |
| --- | --- | --- |
| Original local prototype, Apple Silicon Mac + AirPods Pro | Owner confirmed physical stem mute/unmute; hardware self-test toggled and restored mute | One setup; exact AirPods generation/firmware and call-app matrix were not recorded |
| Swift public-source checkout | See the associated PR and Actions results for SwiftUI/localization, CLI, and fake-device validation | Physical stem behavior must be rechecked after the Swift port; public bundle ID differs from the prototype |
| Intel / other macOS versions / other AirPods | Contributions welcome via compatibility form | A green build is not a hardware pass |

## Manual hardware checklist

Run outside a call or recording. Note the commit, macOS version, Mac architecture, AirPods model/firmware, selected input type, and any call app involved. Do not post device UIDs or personal device names.

1. Record the original mute state. Run `--check`; verify the selected device supports mute.
2. Run `--self-test` only with explicit awareness that it flips real hardware mute, then confirm restoration. A nonzero exit is a failure.
3. Launch, grant permission, and check the status window. If already granted, expect no new permission prompt.
4. Use the configured stem mute gesture twice; verify both UI and actual audio behavior in the intended app. Do not rely solely on its mute icon.
5. Toggle through the menu/window; verify state without counting synchronization callbacks as gestures.
6. Stop/start listening, close/reopen the window, and verify normal quit restores the original state.
7. With a second input available, change the default input and verify its existing mute state is preserved. Check unsupported-device feedback.
8. Disconnect/reconnect a changed device; verify a later normal quit retries restoration.
9. Check permission denial/revocation, sleep/wake, and another app handling AirPods controls. Record failures; these cases are not presumed supported.

Mark unavailable cases as **not tested**, with a reason. Never report an unperformed check as passed.

## Release evidence

Attach the exact commit and completed checklist to the release PR or issue. Record regressions and unknowns in the changelog. Follow [the release checklist](MAINTAINING.md#release-checklist) before creating a tag or distributing a binary.
