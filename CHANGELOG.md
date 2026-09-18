# Changelog

User-visible changes are recorded here. Version tags and releases will be created only after the release checklist is completed; the bundle currently declares development version `0.1.0`.

## Unreleased

### Added

- Native macOS menu bar and status window for default-input microphone mute.
- Compatible AirPods mute gesture handling through public Apple APIs.
- Original mute-state restoration on normal quit, with disconnected device state retained locally.
- Local build, read-only diagnostics, and explicit hardware self-test.
- Non-interactive CLI help/version handling and automated build/bundle checks.
- English/Korean setup documentation, issue forms, PR template, and maintenance guides.

### Known limitations

- Korean UI; compatible hardware mute control is required.
- Physical stem behavior has only been confirmed on one Apple Silicon/AirPods Pro setup.
- No notarized binary download, automatic updater, or login launch.
- Other call apps may compete for AirPods controls; input I/O can affect Bluetooth quality and power use.
