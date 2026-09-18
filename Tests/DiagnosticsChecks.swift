import CoreAudio

private final class DiagnosticDevice: AudioDevices {
    var defaultInput: AudioDeviceID = 1
    var state: Bool?
    var reads = 0
    var unexpectedCalls = 0
    init(_ state: Bool?) { self.state = state }
    func readMute(_ device: AudioDeviceID) -> Bool? {
        require(device == defaultInput, "Diagnostics must read only default input")
        reads += 1
        return state
    }
    func name(_ device: AudioDeviceID) -> String { unexpectedCalls += 1; return "Private name" }
    func uid(_ device: AudioDeviceID) -> String { unexpectedCalls += 1; return "Private UID" }
    func allDevices() -> [AudioDeviceID]? { unexpectedCalls += 1; return [1] }
    func writeMute(_ device: AudioDeviceID, _ muted: Bool) -> Bool { unexpectedCalls += 1; return false }
}

func checkDiagnostics() {
    for state: Bool? in [false, true, nil] {
        let device = DiagnosticDevice(state)
        let report = InputDiagnostic(audio: device)
        let expected = state == nil ? "input=default supported=0 muted=unknown" : "input=default supported=1 muted=\(state! ? 1 : 0)"
        require(report.line == expected, "Diagnostic status must distinguish unknown from unmuted")
        require(report.exitCode == (state == nil ? 1 : 0), "Unsupported diagnostic exit status")
        require(device.reads == 1 && device.unexpectedCalls == 0, "Diagnostics must not write or resolve private metadata")
    }
    print("PASS: private device metadata is never read; diagnostics are read-only and preserve unknown state.")
}
