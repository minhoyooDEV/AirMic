# Maintainer guide

AirMic is a small, experimental project maintained by [@minhoyooDEV](https://github.com/minhoyooDEV). There is no response SLA or promised release schedule.

## Triage

1. Confirm the report includes a commit/version, environment, expected behavior, and reproduction.
2. Use `bug`, `enhancement`, `documentation`, or `question` when appropriate. Add `help wanted` for bounded work with clear acceptance criteria.
3. Separate a build failure from unverified hardware behavior. Ask for missing evidence without requesting raw audio or private device identifiers.
4. Link duplicates to the original. Close resolved issues with the fixing PR; explain scope-based declines. Do not automatically close reports merely because they are old.

## Review and merge

- Prefer one behavior or coherent task per PR; link the motivating issue.
- Require the Build workflow to pass on both configured architectures. The `main` branch requires both checks and an up-to-date PR branch. It also requires resolved review conversations and prohibits force pushes/deletion. Zero external approvals are required for this solo-maintainer project; administrators are not forced through protection.
- For changes affecting audio, permission, or restoration, require the relevant manual checklist and record untested cases.
- Inspect privacy, saved-state migration, error handling, and unsupported-device behavior. Keep runtime dependencies minimal.
- Keep commit subjects meaningful. Squash noisy fixups or preserve a small, coherent series; never fabricate reviews or contributors.
- Update documentation and `CHANGELOG.md`. Do not publish binaries or create a release just because CI passed.

## Release checklist

- [ ] Select a commit with green CI and recorded manual hardware verification of that commit.
- [ ] Review open regressions and document compatibility limits.
- [ ] Update `CFBundleShortVersionString` and increment `CFBundleVersion`.
- [ ] Move `Unreleased` entries to a dated version section.
- [ ] Build from a clean checkout and verify bundle metadata/signature.
- [ ] State architecture, minimum macOS, source commit, and signing/notarization status in release notes.
- [ ] If distributing a binary, establish Developer ID signing/notarization and attach checksums; never imply an ad-hoc build is notarized.
- [ ] Tag the verified commit and publish notes linking the relevant issues/PRs. Mark experimental releases as prereleases.
- [ ] Reproduce installation and removal from the actual published artifact.

The current publication is source only. No tag or binary release is implied by the development bundle version.

`bash scripts/package.sh` creates a local architecture-specific DMG under ignored `build/packages/`. It includes an Applications shortcut and bilingual instructions, verifies the disk image, and writes a checksum. This is for local installation/testing; it does not sign with Developer ID, notarize, tag, or publish a release.

## Workflow upkeep

Actions are pinned to commit SHAs. Dependabot proposes weekly action updates; review upstream changes and let CI pass before merging. The workflow grants `contents: read`, disables persisted checkout credentials, and does not use `pull_request_target`, repository secrets, or hardware tests.

Use [GitHub's runner reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) when changing runner labels. Reassess macOS minimums and public API availability with actual devices before widening claims.
