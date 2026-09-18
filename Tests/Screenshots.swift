import AppKit

// Render the production SwiftUI view with fixture state, without audio I/O or
// reading the user's screen. These images demonstrate UI, not hardware evidence.
func exportScreenshots(directory: String, language: String) {
    let destination = URL(fileURLWithPath: directory)
    try! FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
    for muted in [false, true] {
        let snapshot = StatusWindow()
        let window = snapshot.window!, view = snapshot.window!.contentView!
        window.appearance = NSAppearance(named: .aqua)
        snapshot.render(muted: muted, input: "AirPods Pro", listening: true, message: L("status.listening"))
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let bounds = view.bounds
        let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(bounds.width * 2), pixelsHigh: Int(bounds.height * 2), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        image.size = bounds.size
        view.cacheDisplay(in: bounds, to: image)
        let data = image.representation(using: .png, properties: [:])!
        try! data.write(to: destination.appendingPathComponent("airmic-\(language)-\(muted ? "muted" : "ready").png"))
    }
    print("PASS: exported production UI with fixture state; no screen capture or audio I/O.")
}
