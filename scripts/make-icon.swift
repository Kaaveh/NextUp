// swift scripts/make-icon.swift → Support/AppIcon.icns. Calendar style: red NEXT over a big UP.
// Run it from the repo root after changing the drawing; the .icns is committed, builds don't run this.
import AppKit

let red = NSColor(srgbRed: 0.98, green: 0.24, blue: 0.22, alpha: 1)
let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)

// Draws on a 1024 grid scaled to `px`: an 824 body with a 185 corner radius, as macOS icons use.
func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = CGFloat(px) / 1024
    let scale = NSAffineTransform()
    scale.scale(by: k)
    scale.concat()

    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20 * k
    shadow.shadowOffset = NSSize(width: 0, height: -10 * k)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185).fill()
    NSGraphicsContext.restoreGraphicsState()

    func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat, kern: CGFloat = 0) {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let str = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern])
        // centre the cap height, not the line box
        str.draw(at: NSPoint(x: (1024 - str.size().width + kern) / 2, y: centerY - font.capHeight / 2 + font.descender))
    }
    text("NEXT", size: 150, weight: .semibold, color: red, centerY: 740, kern: 6)
    text("UP", size: 400, weight: .regular, color: ink, centerY: 420)

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let set = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: set)
try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try! png(pt).write(to: set.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try! png(pt * 2).write(to: set.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
let iconutil = try! Process.run(URL(fileURLWithPath: "/usr/bin/iconutil"),
                                arguments: ["-c", "icns", "-o", "Support/AppIcon.icns", set.path])
iconutil.waitUntilExit()
exit(iconutil.terminationStatus)
