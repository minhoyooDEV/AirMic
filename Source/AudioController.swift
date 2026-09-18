import Foundation
import CoreAudio

protocol AudioDevices {
    var defaultInput: AudioDeviceID { get }
    func uid(_ device: AudioDeviceID) -> String
    func name(_ device: AudioDeviceID) -> String
    func readMute(_ device: AudioDeviceID) -> Bool?
    func writeMute(_ device: AudioDeviceID, _ muted: Bool) -> Bool
    func allDevices() -> [AudioDeviceID]?
}

struct SystemAudioDevices: AudioDevices {
    var defaultInput: AudioDeviceID {
        var device: AudioDeviceID = 0
        var size = UInt32(MemoryLayout.size(ofValue: device))
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else { return 0 }
        return device
    }

    private func string(_ device: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String {
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout.size(ofValue: value))
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        guard device != 0, AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr, let result = value else { return "" }
        return result.takeRetainedValue() as String
    }

    func uid(_ device: AudioDeviceID) -> String { string(device, kAudioDevicePropertyDeviceUID) }
    func name(_ device: AudioDeviceID) -> String { string(device, kAudioObjectPropertyName) }

    func readMute(_ device: AudioDeviceID) -> Bool? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: 0)
        var writable: DarwinBoolean = false
        guard device != 0, AudioObjectIsPropertySettable(device, &address, &writable) == noErr, writable.boolValue else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    func writeMute(_ device: AudioDeviceID, _ muted: Bool) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: kAudioDevicePropertyScopeInput, mElement: 0)
        var value: UInt32 = muted ? 1 : 0
        guard AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: value)), &value) == noErr else { return false }
        return readMute(device) == muted
    }

    func allDevices() -> [AudioDeviceID]? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return nil }
        guard size > 0 else { return [] }
        var devices = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        let result = devices.withUnsafeMutableBytes {
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, $0.baseAddress!)
        }
        guard result == noErr else { return nil }
        return Array(devices.prefix(Int(size) / MemoryLayout<AudioDeviceID>.size))
    }
}

final class MuteController {
    private let audio: AudioDevices
    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private var originals: [String: Bool]
    private var error = ""
    private var callbacks: UInt = 0

    init(audio: AudioDevices = SystemAudioDevices(), defaults: UserDefaults = .standard) {
        self.audio = audio
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: "OriginalMuteStates") ?? [:]
        originals = saved.compactMapValues { ($0 as? NSNumber)?.boolValue }
    }

    var state: (error: String, callbacks: UInt) {
        lock.lock(); defer { lock.unlock() }
        return (error, callbacks)
    }

    func handleMute(_ muted: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        callbacks += 1
        return apply(muted)
    }

    func apply(_ muted: Bool) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let device = audio.defaultInput
        let uid = audio.uid(device)
        guard let prior = audio.readMute(device), !uid.isEmpty else {
            error = L("error.unsupported_input"); return false
        }
        if originals[uid] == nil {
            originals[uid] = prior
            defaults.set(originals, forKey: "OriginalMuteStates")
        }
        guard audio.writeMute(device, muted) else {
            _ = audio.writeMute(device, prior)
            error = L("error.mute_verification"); return false
        }
        error = ""
        return true
    }

    func restore() -> [String] {
        lock.lock(); defer { lock.unlock() }
        guard let devices = audio.allDevices() else { return [L("error.device_list")] }
        var failures: [String] = []
        for device in devices {
            let uid = audio.uid(device)
            guard let prior = originals[uid] else { continue }
            if audio.writeMute(device, prior) { originals.removeValue(forKey: uid) }
            else { failures.append(audio.name(device)) }
        }
        // Keep disconnected/failed devices for a later launch and normal quit.
        defaults.set(originals, forKey: "OriginalMuteStates")
        return failures
    }
}
