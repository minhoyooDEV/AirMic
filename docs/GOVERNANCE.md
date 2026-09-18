# Project governance

AirMic is an independent, MIT-licensed utility maintained by [@minhoyooDEV](https://github.com/minhoyooDEV). It is an early experimental project, not a foundation or a vendor-backed product. The maintainer currently has final responsibility for scope, review, releases, and security response. There is no promised support schedule.

## Decisions and contributions

Use public issues for reproducible bugs, compatibility results, and focused proposals; use private vulnerability reporting for security details. Decisions should explain user impact, privacy implications, maintenance cost, and the evidence supporting a change. Contributors retain attribution through Git history and PRs. No CLA is required; contributions use the project's MIT license.

Code review and required CI precede merge. Audio changes also need the applicable manual evidence or an explicit statement that physical checks are still pending. A beta label does not turn automated tests into hardware evidence. Stable releases require the release checklist in [MAINTAINING.md](MAINTAINING.md).

An additional maintainer role can be discussed after sustained, reviewed contributions. Repository access is not automatic, and nobody is listed as a maintainer or sponsor without their agreement. If maintenance stops, the owner should disclose that status in the README; the MIT license permits forks.

## Useful ways to help now

- Report physical AirPods/input-device behavior using the [compatibility form](https://github.com/minhoyooDEV/AirMic/issues/new?template=compatibility.yml), including failures and untested cases.
- Review Korean, Simplified Chinese, Japanese, Spanish, and English UI text in context.
- Reproduce a reported failure with a fake-device regression test before changing audio state handling.
- Check keyboard use, VoiceOver descriptions, contrast, and Reduce Transparency behavior, and report concrete results.
- Improve installation instructions based on the actual published beta, including its signing limits.

## AI-assisted contributions

AI assistance is welcome. The submitting contributor must understand the change, review permissions and data handling, and run the relevant checks. Identify material AI assistance in the PR along with what a human or automated check actually verified. Do not present an AI-generated review as an independent human approval.

Codex is used as a development aid for focused implementation, test creation, documentation, and PR preparation. AirMic itself has no AI service dependency or network path. Future automation should start with read-only triage or draft review, keep credentials out of untrusted pull-request execution, and leave release and security decisions with maintainers. No paid automation or external security service is configured by this document.

## Evidence over appearance

Release downloads are download counts, not unique users. Stars and forks are interest signals, not proof of adoption. Application/program eligibility, sponsorship, and security claims must link to verified evidence. Current usage is not instrumented. Support applications should state the project's early stage and concrete maintenance needs rather than implying broad adoption.
