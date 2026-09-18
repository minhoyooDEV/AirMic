# Working on AirMic

AirMic is a local macOS microphone utility written in Swift/SwiftUI. Keep changes focused on the default input and compatible AirPods controls. Read `CONTRIBUTING.md`, `docs/ARCHITECTURE.md`, and the affected source before modifying behavior.

## Checks

- `bash scripts/check.sh`: build, CLI, translations, SwiftUI sizing, fake-device restoration, private diagnostics, and generated website freshness. Requires macOS and Apple developer tools; it does not start real audio I/O.
- `python3 scripts/build-site.py --check`: website-only freshness check, Python 3 standard library, no macOS requirement.
- Edit `site/content.json` and `scripts/build-site.py` before regenerating `docs/*/index.html`; do not hand-edit generated pages.
- `--self-test` changes the real microphone. Run hardware tests only when the user explicitly authorizes them and no call/recording is active. Never infer hardware compatibility from CI or fixture screenshots.

## Review boundaries

- Never read, retain, transmit, or record microphone buffers. Do not add network requests, telemetry, third-party audio drivers, privileged helpers, or new runtime dependencies without a reviewed scope change.
- Preserve the first original mute state and restoration retries. Do not erase failed/disconnected snapshots to make tests pass. Test failures with injectable fake devices.
- Keep device names, UIDs, local paths, recordings, and credentials out of public diagnostics, issues, screenshots, and commits.
- User-facing strings belong in all five localization tables. Keep CLI diagnostics stable and English.
- Do not alter system privacy settings, disable Gatekeeper, accept Apple license agreements, or run an installed app just to test documentation.
- Keep beta signing status and untested cases visible. Do not claim endorsement, funding, usage, contributor counts, security certification, or hardware evidence that has not been verified.
- Use focused PRs; describe actual validation and remaining limits. Respect required CI and the maintainer's merge policy. Do not fabricate activity or reviews.

No OpenAI API key is needed to build or use AirMic. Codex may assist development, but maintainers remain responsible for every merged change.
