# Contributing to AirMic

Small, reproducible improvements are welcome. English and Korean are both fine.

For interface translations, follow [the localization guide](docs/LOCALIZATION.md). Keep user-facing text in language resources and include the microphone permission purpose for every supported language.

## Before changing code

- Search existing issues; use the bug or compatibility form for device-specific behavior.
- Discuss changes to audio routing, permissions, storage, or distribution in an issue first.
- Keep runtime dependencies and background activity small. Audio recording, telemetry, and third-party drivers are outside the current scope.
- Use [SECURITY.md](SECURITY.md) for vulnerabilities. Remove personal device names, identifiers, paths, and meeting details from reports.

## Local workflow

1. Fork and create a branch such as `fix/restore-error` or `docs/permissions`.
2. Build and run `bash scripts/check.sh` on macOS. This does not activate audio input.
3. For audio behavior changes, follow [the manual checklist](docs/TESTING.md) outside calls or recordings.
4. Update both READMEs when user-facing behavior changes and add a short entry under `Unreleased` in `CHANGELOG.md`.
5. Open a focused PR with the problem, resulting behavior, and actual validation. Explicitly list untested hardware cases.

## First contributions

See [governance and current contribution paths](docs/GOVERNANCE.md) for translation review, compatibility reports, accessibility checks, and fake-device regression tests. AI-assisted changes are welcome when you review them, disclose material assistance, and report actual checks. Repository-specific agent guidance is in [AGENTS.md](AGENTS.md).

## Commits and review

Use imperative, descriptive subjects. A prefix such as `fix:`, `feat:`, `docs:`, or `ci:` is encouraged, not enforced. Keep unrelated changes separate; do not manufacture history or rewrite other contributors' commits. Link the issue with `Refs #123`, or `Closes #123` when the PR completes it.

CI must pass before merge. Hardware-affecting changes need a recorded manual checklist; explicitly label unavailable cases as untested. Stable releases require real-device evidence. Maintainers may ask for a smaller change, keep an issue open for more evidence, or decline features that expand the scope. Passing CI alone does not establish audio correctness.

Treat contributors respectfully, focus feedback on the work, and avoid posting others' private information. A maintainer may remove abusive content. Contributions are made under the repository's [MIT license](LICENSE); no CLA is required.
