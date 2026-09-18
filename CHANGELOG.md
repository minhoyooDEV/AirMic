# Changelog

User-visible changes are recorded here. Version tags and releases will be created only after the release checklist is completed; the bundle currently declares development version `0.1.0`.

## Unreleased

### Added

- SwiftUI frosted window with a mostly opaque, airy background, adaptive light/dark colors, accessible native buttons, and a matching app icon.
- Deterministic fake-device checks for mute snapshots, rollback, partial restoration, disconnected retry, and unsupported input.

- Compact Mac window with a microphone icon, prominent mute button, direct help/quit controls, and Dock/app-switcher access while visible.
- Window reopen handling and Command-Q routed through normal microphone restoration.
- Local DMG packaging with an Applications shortcut, bilingual instructions, and SHA-256 checksum.
- English and Korean interface/permission translations using native macOS language preferences, with English fallback.
- Resizable status window with wrapping labels and checks for localization completeness, placeholders, language selection, and layout.
- Native macOS menu bar and status window for default-input microphone mute.
- Compatible AirPods mute gesture handling through public Apple APIs.
- Original mute-state restoration on normal quit, with disconnected device state retained locally.
- Local build, read-only diagnostics, and explicit hardware self-test.
- Non-interactive CLI help/version handling and automated build/bundle checks.
- English/Korean setup documentation, issue forms, PR template, and maintenance guides.

### Changed

- Move app, audio control, and tests to Swift; keep a minimal header for public API compatibility with older SDKs.

### Known limitations

- English/Korean UI; compatible hardware mute control is required.
- Physical stem behavior was confirmed on one Apple Silicon/AirPods Pro prototype; the Swift port still needs a recorded physical check.
- No notarized binary download, automatic updater, or login launch.
- Other call apps may compete for AirPods controls; input I/O can affect Bluetooth quality and power use.
