import AppKit

// Draw the source-owned mark at each icon size; no downloaded artwork or fonts.
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        let tile = NSBezierPath(roundedRect: NSRect(x: 92, y: 92, width: 840, height: 840), xRadius: 188, yRadius: 188)
        NSColor(calibratedRed: 0.89, green: 0.95, blue: 0.97, alpha: 1).setFill()
        tile.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        tile.lineWidth = 6
        tile.stroke()
        NSColor(calibratedRed: 0.25, green: 0.56, blue: 0.63, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 421, y: 404, width: 182, height: 314), xRadius: 91, yRadius: 91).fill()
        let cradle = NSBezierPath()
        cradle.move(to: NSPoint(x: 342, y: 498))
        cradle.line(to: NSPoint(x: 342, y: 450))
        cradle.curve(to: NSPoint(x: 682, y: 450), controlPoint1: NSPoint(x: 342, y: 235), controlPoint2: NSPoint(x: 682, y: 235))
        cradle.line(to: NSPoint(x: 682, y: 498))
        cradle.move(to: NSPoint(x: 512, y: 290)); cradle.line(to: NSPoint(x: 512, y: 220))
        cradle.move(to: NSPoint(x: 422, y: 220)); cradle.line(to: NSPoint(x: 602, y: 220))
        cradle.lineWidth = 34; cradle.lineCapStyle = .round
        NSColor(calibratedRed: 0.25, green: 0.56, blue: 0.63, alpha: 1).setStroke()
        cradle.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: directory).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
