import AppKit
import SwiftUI

struct MicrophoneState: Equatable {
    var muted: Bool?
    var input = ""
    var listening = false
    var message = ""
    var title: String { L(muted.map { $0 ? "state.muted" : "state.unmuted" } ?? "state.unsupported") }
    var symbol: String { muted.map { $0 ? "mic.slash.fill" : "mic.fill" } ?? "exclamationmark.triangle" }
    var action: String { L(muted == true ? "action.unmute" : "action.mute") }
}

final class StatusModel: ObservableObject {
    @Published var state = MicrophoneState()
    var onToggle: (() -> Void)?
    var onListening: (() -> Void)?
    var onHelp: (() -> Void)?
    var onQuit: (() -> Void)?
}

// Older standalone SDKs lack SwiftUI Material; keep that compatibility in one view.
private struct NativeFrost: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct Frost: View {
    var body: some View {
        #if compiler(>=5.5)
        if #available(macOS 12.0, *) { Rectangle().fill(.ultraThinMaterial) }
        else { NativeFrost() }
        #else
        NativeFrost()
        #endif
    }
}

private struct AirBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var dark: Bool { scheme == .dark }

    var body: some View {
        ZStack {
            Frost()
            Color(red: dark ? 0.12 : 0.97, green: dark ? 0.14 : 0.98, blue: dark ? 0.16 : 0.99)
                .opacity(reduceTransparency ? 1 : 0.96)
            // Broad, radial washes suggest air without a directional seam.
            RadialGradient(gradient: Gradient(colors: [Color(red: 0.57, green: 0.79, blue: 0.9).opacity(dark ? 0.13 : 0.2), .clear]), center: .topLeading, startRadius: 0, endRadius: 380)
            RadialGradient(gradient: Gradient(colors: [Color(red: 0.68, green: 0.84, blue: 0.84).opacity(dark ? 0.07 : 0.13), .clear]), center: .bottomTrailing, startRadius: 0, endRadius: 260)
        }
    }
}

private struct AirButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var enabled
    var prominent = false
    private var dark: Bool { scheme == .dark }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: prominent ? 13 : 11, weight: prominent ? .semibold : .medium))
            .frame(maxWidth: .infinity)
            .frame(height: prominent ? 40 : 30)
            .foregroundColor(prominent ? (dark ? .black : .white) : .primary)
            .background(Capsule().fill(prominent ? (dark ? Color(white: 0.94) : Color(white: 0.13)) : Color.primary.opacity(dark ? 0.06 : 0.035)))
            .overlay(Capsule().stroke(Color.primary.opacity(prominent ? 0 : 0.06), lineWidth: 0.75))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .contentShape(Capsule())
    }
}

private struct MicrophoneMark: View {
    @Environment(\.colorScheme) private var scheme
    let state: MicrophoneState
    private var tint: Color {
        guard let muted = state.muted else { return .secondary }
        return muted ? Color(red: 0.76, green: 0.3, blue: 0.34) : Color(red: 0.23, green: 0.57, blue: 0.64)
    }
    var body: some View {
        Image(systemName: state.symbol)
            .font(.system(size: 27, weight: .regular))
            .foregroundColor(tint)
            .frame(width: 60, height: 60)
            .background(RoundedRectangle(cornerRadius: 19, style: .continuous).fill(Color.white.opacity(scheme == .dark ? 0.07 : 0.68)))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Color.white.opacity(scheme == .dark ? 0.15 : 0.9), lineWidth: 1))
            .shadow(color: tint.opacity(0.08), radius: 16, x: 0, y: 8)
            .accessibilityHidden(true)
    }
}

struct StatusView: View {
    @ObservedObject var model: StatusModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text("AirMic").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                .padding(.bottom, 12)
            MicrophoneMark(state: model.state).padding(.bottom, 12)
            Text(model.state.title).font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center).frame(maxWidth: 288).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
            Text(LF("device.input", model.state.input)).font(.system(size: 12))
                .foregroundColor(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).padding(.bottom, 10)
            HStack(spacing: 6) {
                Circle().fill(model.state.listening ? Color(red: 0.27, green: 0.61, blue: 0.52) : Color.secondary.opacity(0.5))
                    .frame(width: 5, height: 5).accessibilityHidden(true)
                Text(model.state.message).font(.system(size: 11))
                    .foregroundColor(.secondary).multilineTextAlignment(.center).frame(maxWidth: 228)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.035)))
            .padding(.bottom, 12)
            Button(model.state.action) { model.onToggle?() }
                .buttonStyle(AirButtonStyle(prominent: true))
                .disabled(model.state.muted == nil)
                .accessibilityIdentifier("toggle-mute")
                .padding(.bottom, 8)
            Button(L(model.state.listening ? "action.stop_listening" : "action.start_listening")) { model.onListening?() }
                .buttonStyle(AirButtonStyle())
                .padding(.bottom, 12)
            HStack(spacing: 24) {
                Button(L("action.help")) { model.onHelp?() }
                Button(L("action.quit_short")) { model.onQuit?() }
            }
            .buttonStyle(PlainButtonStyle()).font(.system(size: 11)).foregroundColor(.secondary)
            .padding(.bottom, 10)
            Label(L("privacy.summary"), systemImage: "lock.shield")
                .font(.system(size: 9)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 16)
        .frame(minWidth: 336, maxWidth: .infinity, minHeight: 362, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(AirBackground().ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16))
    }
}

final class StatusWindow: NSWindowController, NSWindowDelegate {
    let model = StatusModel()
    var onToggle: (() -> Void)? { get { model.onToggle } set { model.onToggle = newValue } }
    var onListening: (() -> Void)? { get { model.onListening } set { model.onListening = newValue } }
    var onHelp: (() -> Void)? { get { model.onHelp } set { model.onHelp = newValue } }
    var onQuit: (() -> Void)? { get { model.onQuit } set { model.onQuit = newValue } }
    var onClose: (() -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 336, height: 362),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "AirMic"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentMinSize = NSSize(width: 336, height: 362)
        window.delegate = self
        window.standardWindowButton(.closeButton)?.toolTip = L("window.close_hint")
        window.contentView = NSHostingView(rootView: StatusView(model: model))
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func render(muted: Bool?, input: String, listening: Bool, message: String) {
        let state = MicrophoneState(muted: muted, input: input, listening: listening, message: message)
        if state != model.state { model.state = state }
    }
    func present() {
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
}
