import Foundation

/// A support report with a fixed allowlist of fields. Never resolves device
/// names/UIDs or changes mute state; nil is unknown, not evidence of being live.
struct InputDiagnostic {
    let muted: Bool?
    init(audio: AudioDevices) {
        muted = audio.readMute(audio.defaultInput)
    }
    var line: String {
        let state = muted.map { $0 ? "1" : "0" } ?? "unknown"
        return "input=default supported=\(muted == nil ? 0 : 1) muted=\(state)"
    }
    var exitCode: Int32 { muted == nil ? 1 : 0 }
}
