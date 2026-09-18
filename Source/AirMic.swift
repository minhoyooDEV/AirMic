import AppKit
import AVFoundation
import AudioToolbox

final class AirMicDelegate: NSObject, NSApplicationDelegate {
    private let audio = SystemAudioDevices()
    private lazy var control = MuteController(audio: audio)
    private var audioApp: NSObject?
    private var audioUnit: AudioUnit?
    private var status: NSStatusItem?
    private var timer: Timer?
    private var notification: NSObjectProtocol?
    private var window: StatusWindow?
    private var listening = false
    private var requesting = false
    private var watchedDevice: AudioDeviceID = 0
    private var message = ""
    private let deviceLine = NSMenuItem()
    private let stateLine = NSMenuItem()
    private let eventLine = NSMenuItem()
    private var toggleLine = NSMenuItem()
    private var listenLine = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        message = L("status.ready")
        audioApp = AMSharedAudioApplication()
        if let name = AMMuteNotificationName() {
            self.notification = NotificationCenter.default.addObserver(forName: NSNotification.Name(name), object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status = item
        let menu = NSMenu()
        [deviceLine, stateLine, eventLine].forEach { menu.addItem($0) }
        menu.addItem(.separator())
        toggleLine = addItem(menu, "action.toggle", #selector(toggle))
        listenLine = addItem(menu, "action.start_listening", #selector(changeListening))
        addItem(menu, "action.help", #selector(help))
        addItem(menu, "action.show_window", #selector(showStatus))
        menu.addItem(.separator())
        addItem(menu, "action.quit_restore", #selector(quit), key: "q")
        item.menu = menu
        NSApp.mainMenu = applicationMenu()
        watchedDevice = audio.defaultInput
        showStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
        changeListening()
    }

    @discardableResult
    private func addItem(_ menu: NSMenu, _ key: String, _ action: Selector, key equivalent: String = "") -> NSMenuItem {
        let item = menu.addItem(withTitle: L(key), action: action, keyEquivalent: equivalent)
        item.target = self
        return item
    }

    func applicationMenu() -> NSMenu {
        let menu = NSMenu()
        let root = menu.addItem(withTitle: "AirMic", action: nil, keyEquivalent: "")
        let appMenu = NSMenu(title: "AirMic")
        root.submenu = appMenu
        addItem(appMenu, "action.help", #selector(help))
        appMenu.addItem(.separator())
        addItem(appMenu, "action.quit_restore", #selector(quit), key: "q")
        return menu
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatus()
        return false
    }

    @objc private func showStatus() {
        if window == nil {
            let view = StatusWindow()
            view.onToggle = { [weak self] in self?.toggle() }
            view.onListening = { [weak self] in self?.changeListening() }
            view.onHelp = { [weak self] in self?.help() }
            view.onQuit = { NSApp.terminate(nil) }
            view.onClose = { NSApp.setActivationPolicy(.accessory) }
            window = view
        }
        window?.present()
    }

    private func refresh() {
        let device = audio.defaultInput
        let muted = audio.readMute(device)
        if device != watchedDevice {
            watchedDevice = device
            if listening { stop(); startEngine() }
        }
        let state = control.state
        deviceLine.title = LF("device.input", audio.name(device))
        stateLine.title = muted.map { L($0 ? "state.muted" : "state.unmuted") } ?? L("state.unsupported")
        let symbol = muted.map { $0 ? "mic.slash.fill" : "mic.fill" } ?? "exclamationmark.triangle"
        status?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: stateLine.title)
        status?.button?.toolTip = "AirMic · \(stateLine.title)\n\(message)"
        eventLine.title = listening ? LF("status.events", state.callbacks) : message
        listenLine.title = L(listening ? "action.stop_listening" : "action.start_listening")
        toggleLine.isEnabled = muted != nil
        toggleLine.title = L(muted == true ? "action.unmute" : "action.mute")
        let detail = !state.error.isEmpty ? state.error : (listening ? L("status.listening") : message)
        window?.render(muted: muted, input: audio.name(device), listening: listening, message: detail)
    }

    @objc private func toggle() {
        guard let muted = audio.readMute(audio.defaultInput) else { return }
        let success = control.apply(!muted)
        if success, let app = audioApp {
            _ = AMSetMuteHandler(app, nil)
            _ = AMSetInputMuted(app, !muted)
            if listening { _ = registerHandler() }
        }
        message = success ? L("status.changed") : control.state.error
        if !success { NSSound.beep() }
        refresh()
    }

    private func registerHandler() -> Bool {
        guard let app = audioApp else { return false }
        let controller = control
        let success = AMSetMuteHandler(app) { [weak controller] muted in controller?.handleMute(muted) ?? false }
        if !success { message = L("error.handler") }
        return success
    }

    private func startEngine() {
        guard let app = audioApp else { message = L("error.os_version"); refresh(); return }
        guard let muted = audio.readMute(audio.defaultInput) else { message = L("error.current_input"); refresh(); return }
        _ = AMSetInputMuted(app, muted)
        guard registerHandler() else { refresh(); return }
        var description = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_HALOutput, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var unit: AudioUnit?
        var result: OSStatus = -1
        if let component = AudioComponentFindNext(nil, &description) { result = AudioComponentInstanceNew(component, &unit) }
        if let created = unit, result == noErr {
            var on: UInt32 = 1, off: UInt32 = 0
            var device = audio.defaultInput
            result = AudioUnitSetProperty(created, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &on, UInt32(MemoryLayout.size(ofValue: on)))
            if result == noErr { result = AudioUnitSetProperty(created, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &off, UInt32(MemoryLayout.size(ofValue: off))) }
            if result == noErr { result = AudioUnitSetProperty(created, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, UInt32(MemoryLayout.size(ofValue: device))) }
            // Input I/O stays active for controls, but no audio buffers are read.
            var callback = AURenderCallbackStruct(inputProc: { _, _, _, _, _, _ in noErr }, inputProcRefCon: nil)
            if result == noErr { result = AudioUnitSetProperty(created, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, UInt32(MemoryLayout.size(ofValue: callback))) }
            if result == noErr { result = AudioUnitInitialize(created) }
            if result == noErr { result = AudioOutputUnitStart(created) }
        }
        if result == noErr, let created = unit {
            audioUnit = created; listening = true; message = L("status.detecting")
        } else {
            if let created = unit { AudioOutputUnitStop(created); AudioComponentInstanceDispose(created) }
            _ = AMSetMuteHandler(app, nil)
            message = LF("error.input_start", result)
        }
        refresh()
    }

    @objc private func changeListening() {
        if listening { stop(); message = L("status.stopped"); refresh(); return }
        guard !requesting else { return }
        requesting = true
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.requesting = false
                if granted { self.startEngine() }
                else { self.message = L("error.permission"); self.refresh() }
            }
        }
    }

    private func stop() {
        listening = false
        if let app = audioApp { _ = AMSetMuteHandler(app, nil) }
        if let unit = audioUnit {
            AudioOutputUnitStop(unit); AudioUnitUninitialize(unit); AudioComponentInstanceDispose(unit)
            audioUnit = nil
        }
    }

    @objc private func help() {
        let alert = NSAlert()
        alert.messageText = "AirMic"
        alert.informativeText = L("help.body")
        alert.addButton(withTitle: L("action.ok"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        stop()
        let failures = control.restore()
        if !failures.isEmpty {
            let alert = NSAlert()
            alert.messageText = L("error.restore_title")
            alert.informativeText = failures.joined(separator: ", ")
            alert.addButton(withTitle: L("action.cancel_quit"))
            alert.addButton(withTitle: L("action.quit_anyway"))
            if alert.runModal() == .alertFirstButtonReturn { refresh(); return .terminateCancel }
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let token = self.notification { NotificationCenter.default.removeObserver(token) }
    }
}

#if !AIRMIC_TESTING
@main
enum AirMic {
    static func main() {
        let args = Array(CommandLine.arguments.dropFirst())
        let usage = """
        Usage: AirMic [--help | --version | --check | --self-test]
          No arguments  Open the menu bar app and request microphone access.
          --help        Show this help without accessing audio hardware.
          --version     Show the bundle version without accessing audio hardware.
          --check       Read default input mute status; omit device names/IDs.
          --self-test   Flip real hardware mute, then attempt to restore it.
                        Run only outside calls and recordings.

        """
        guard args.count <= 1 else { fputs(usage, stderr); exit(64) }
        if let option = args.first {
            switch option {
            case "--help": print(usage, terminator: ""); return
            case "--version":
                guard let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { exit(1) }
                print("AirMic \(version)"); return
            case "--check":
                let report = InputDiagnostic(audio: SystemAudioDevices())
                print(report.line)
                exit(report.exitCode)
            case "--self-test":
                let audio = SystemAudioDevices(), device = SystemAudioDevices().defaultInput
                guard let prior = audio.readMute(device) else { exit(1) }
                let changed = audio.writeMute(device, !prior)
                let restored = audio.writeMute(device, prior)
                let verified = audio.readMute(device) == prior
                print("toggle=\(changed ? 1 : 0) restore=\(restored ? 1 : 0) verified=\(verified ? 1 : 0)")
                exit(changed && restored && verified ? 0 : 1)
            default: fputs("Unknown option: \(option)\n" + usage, stderr); exit(64)
            }
        }
        let app = NSApplication.shared
        let delegate = AirMicDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif
