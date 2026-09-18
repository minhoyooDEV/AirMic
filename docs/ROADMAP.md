# Roadmap

These are directions for discussion, not scheduled commitments. Track implementation and evidence in [Issues](https://github.com/minhoyooDEV/AirMic/issues).

| Priority | Work | Done when |
| --- | --- | --- |
| Next | Broader compatibility evidence | Reports identify commit, macOS, architecture, AirPods/input model, and actual audio behavior |
| Next | English UI and localization structure | All user-facing strings are localized, both languages are reviewed, and behavior is unchanged |
| Later | Isolate mute/restoration state for deterministic tests | Device disconnects, write failures, and restoration retry can be simulated without microphone hardware |
| Later | Signed distribution | Maintainer has a signing/notarization process and verifies installation/removal of release artifacts |

Current scope stays focused on the default input and compatible AirPods events. Virtual drivers, audio recording, cloud accounts, analytics, and an automatic updater are not planned.
