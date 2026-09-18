# Security policy

AirMic is an experimental local macOS utility. Only the latest source on `main` receives fixes; there is no stable release support window yet.

## Report privately

Use GitHub's [private vulnerability reporting](https://github.com/minhoyooDEV/AirMic/security/advisories/new). If the reporting form is unavailable, open an issue asking the maintainer to enable a private channel **without including vulnerability details**. Do not attach recordings, credentials, personal device identifiers, or private meeting content.

Include the affected commit, macOS version, a minimal reproduction, expected versus observed behavior, and potential impact. No response deadline or bounty is promised.

## Boundaries

- The app requests microphone access and activates input I/O for AirPods events. Its input callback does not read or retain microphone buffers.
- Saved defaults contain original device UIDs and mute values so normal quit can retry restoration. Keep these identifiers out of public reports.
- There is no networking, telemetry, updater, driver installation, or privileged helper in the app.
- Device-level mute is not an end-to-end guarantee that another application is silent. The device selected by that application matters.
- A crash, force quit, or disconnect can leave mute state changed. See [recovery instructions](docs/TROUBLESHOOTING.md).

CI uses a read-only repository token and does not run real microphone tests. Build outputs are locally signed, not notarized distributions.
