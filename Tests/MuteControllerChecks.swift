import Foundation
import CoreAudio

private final class FakeAudio: AudioDevices {
    var defaultInput: AudioDeviceID = 1
    var states: [AudioDeviceID: Bool] = [1: false, 2: true]
    var connected: [AudioDeviceID]? = [1, 2]
    var failWrites = Set<AudioDeviceID>()
    var failNextWrite = false
    var writes: [(AudioDeviceID, Bool)] = []
    func uid(_ device: AudioDeviceID) -> String { "test-device-\(device)" }
    func name(_ device: AudioDeviceID) -> String { "Test input \(device)" }
    func readMute(_ device: AudioDeviceID) -> Bool? { states[device] }
    func allDevices() -> [AudioDeviceID]? { connected }
    func writeMute(_ device: AudioDeviceID, _ muted: Bool) -> Bool {
        writes.append((device, muted))
        if failWrites.contains(device) { return false }
        states[device] = muted
        if failNextWrite { failNextWrite = false; return false }
        return true
    }
}

func checkMuteRestoration() {
    let suite = "local.airmic.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let audio = FakeAudio()
    let subject = MuteController(audio: audio, defaults: defaults)
    require(subject.handleMute(true), "Mute should succeed")
    require(subject.handleMute(true), "Repeated events should be idempotent")
    require(subject.handleMute(false), "Unmute should succeed")
    require(subject.state.callbacks == 3, "Callback count")
    require(defaults.dictionary(forKey: "OriginalMuteStates")?["test-device-1"] as? Bool == false, "First original must survive repeated events")
    audio.defaultInput = 2
    require(subject.apply(false), "Second input should mute independently")
    audio.failWrites = [2]
    require(subject.restore() == ["Test input 2"], "Partial restoration should report failed device")
    require(audio.states[1] == false, "First device restored")
    require(defaults.dictionary(forKey: "OriginalMuteStates")?.count == 1, "Only failed snapshot retained")
    audio.failWrites = []
    audio.connected = [1]
    require(subject.restore().isEmpty, "Disconnected device is deferred")
    require(defaults.dictionary(forKey: "OriginalMuteStates")?.count == 1, "Disconnected snapshot retained")
    audio.connected = nil
    require(!subject.restore().isEmpty, "Enumeration failure must be visible")
    require(defaults.dictionary(forKey: "OriginalMuteStates")?.count == 1, "Enumeration failure retains snapshot")
    audio.connected = [1, 2]
    let relaunched = MuteController(audio: audio, defaults: defaults)
    require(relaunched.restore().isEmpty && audio.states[2] == true, "Relaunch retries persistent snapshot")
    require(defaults.dictionary(forKey: "OriginalMuteStates")?.isEmpty == true, "Success clears snapshot")
    audio.defaultInput = 1
    audio.failNextWrite = true
    require(!relaunched.apply(true), "Unverified change must fail")
    require(audio.states[1] == false && audio.writes.last?.1 == false, "Failure rolls back preceding state")
    require(!relaunched.state.error.isEmpty, "Failure reports an error")
    require(relaunched.apply(true) && relaunched.state.error.isEmpty, "Success clears error")
    audio.defaultInput = 99
    let before = audio.writes.count
    require(!relaunched.apply(true) && audio.writes.count == before, "Unsupported input never writes")
    require(defaults.dictionary(forKey: "OriginalMuteStates")?["test-device-99"] == nil, "Unsupported input never saves a snapshot")
    require(relaunched.restore().isEmpty && audio.states[1] == false, "Final restoration")
    print("PASS: mute idempotence, rollback, device switch, partial/disconnected restoration, persistence, and unsupported input (fake devices).")
}
