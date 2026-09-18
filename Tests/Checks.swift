import AppKit
import CoreAudio

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
}

private func table(_ language: String, _ name: String) -> [String: String] {
    let url = Bundle.main.resourceURL!.appendingPathComponent("\(language).lproj/\(name).strings")
    let data = try! Data(contentsOf: url)
    let values = try! PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return values as! [String: String]
}

private func formats(_ value: String) -> [String] {
    let pattern = try! NSRegularExpression(pattern: "%(?:lu|d|@|%)")
    let range = NSRange(value.startIndex..., in: value)
    let stripped = pattern.stringByReplacingMatches(in: value, range: range, withTemplate: "")
    require(!stripped.contains("%"), "Unsupported format token")
    return pattern.matches(in: value, range: range).map { (value as NSString).substring(with: $0.range) }
}

private func checkResources(_ expected: String) {
    let english = table("en", "Localizable"), keys = Set(table("en", "Localizable").keys)
    for language in Bundle.main.localizations {
        let values = table(language, "Localizable")
        require(Set(values.keys) == keys, "Localization keys differ: \(language)")
        for key in keys {
            require(!(values[key] ?? "").isEmpty, "Empty translation: \(key)")
            require(formats(english[key]!) == formats(values[key]!), "Format mismatch: \(key)")
        }
        require(!(table(language, "InfoPlist")["NSMicrophoneUsageDescription"] ?? "").isEmpty, "Missing permission purpose")
    }
    require(Bundle.main.preferredLocalizations.first == expected, "Wrong language selection/fallback")
    for (key, value) in table(expected, "Localizable") { require(L(key) == value, "Unresolved key: \(key)") }
    require(Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String == table(expected, "InfoPlist")["NSMicrophoneUsageDescription"], "Permission purpose did not localize")

    let directory = UserDefaults.standard.string(forKey: "SourceDirectory")!
    let files = try! FileManager.default.contentsOfDirectory(atPath: directory).filter { $0.hasSuffix(".swift") }
    require(!files.isEmpty, "Missing production source")
    // Include keys passed through helpers and ternaries, not only direct L calls.
    let pattern = try! NSRegularExpression(pattern: "\"((?:action|state|status|error|device|help|privacy|window)\\.[a-z_]+)\"")
    for file in files {
        let source = try! String(contentsOfFile: directory + "/" + file, encoding: .utf8)
        for match in pattern.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            let key = (source as NSString).substring(with: match.range(at: 1))
            require(keys.contains(key), "Missing source key: \(key)")
        }
    }
    print("PASS: language=\(expected), \(keys.count) keys, format placeholders, permission purpose.")
}

private func checkWindow(_ subject: StatusWindow) {
    let window = subject.window!, root = subject.window!.contentView!
    require(window.delegate === subject, "Window close lifecycle is not connected")
    for appearance in [NSAppearance.Name.aqua, .darkAqua] {
        window.appearance = NSAppearance(named: appearance)
        for muted: Bool? in [false, true, nil] {
            for key in ["status.listening", "error.permission", "error.current_input", "error.mute_verification"] {
                subject.render(muted: muted, input: "AirPods Pro", listening: muted == false, message: L(key))
                root.layoutSubtreeIfNeeded()
                require(subject.model.state.muted == muted && subject.model.state.message == L(key), "Presentation state did not update")
                require(root.fittingSize.width <= 337 && root.fittingSize.height <= 420, "SwiftUI content exceeds compact window: \(root.fittingSize), \(key), \(String(describing: muted))")
                require(!subject.model.state.title.isEmpty && !subject.model.state.action.isEmpty, "Missing state text")
            }
        }
    }
    var closes = 0
    subject.onClose = { closes += 1 }
    subject.windowWillClose(Notification(name: NSWindow.willCloseNotification))
    require(closes == 1, "Close action is not connected")
    let delegate = AirMicDelegate() // No app delegate installation or audio lifecycle.
    let quit = delegate.applicationMenu().items.first!.submenu!.items.last!
    require(quit.title == L("action.quit_restore") && quit.keyEquivalent == "q" && quit.target === delegate, "Command-Q must use normal termination")
    print("PASS: light/dark SwiftUI sizing, presentation states, and quit menu. No audio I/O.")
}

@main
enum Checks {
    static func main() {
        guard let expected = UserDefaults.standard.string(forKey: "ExpectedLanguage") else { fatalError("Pass -ExpectedLanguage") }
        checkResources(expected)
        checkMuteRestoration()
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let subject = StatusWindow()
        checkWindow(subject)
        if UserDefaults.standard.bool(forKey: "ShowPreview") {
            let dark = UserDefaults.standard.string(forKey: "Appearance") == "dark"
            subject.window?.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            var muted = false, listening = true
            let render = { subject.render(muted: muted, input: "AirPods Pro", listening: listening, message: L(listening ? "status.listening" : "status.stopped")) }
            subject.onToggle = { muted.toggle(); render() }
            subject.onListening = { listening.toggle(); render() }
            subject.onClose = { app.terminate(nil) }
            subject.onQuit = { app.terminate(nil) }
            subject.onHelp = {
                let alert = NSAlert(); alert.messageText = "AirMic"; alert.informativeText = L("help.body"); alert.runModal()
            }
            render()
            subject.present()
            withExtendedLifetime(subject) { app.run() }
        }
    }
}
