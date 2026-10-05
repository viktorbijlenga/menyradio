// Original vector artwork for Menyradio. Regenerate from the repository root:
// swift scripts/generate-icon.swift
// iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func rounded(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func draw(size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let navy = NSColor(srgbRed: 0.10, green: 0.19, blue: 0.28, alpha: 1)
    let cream = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.89, alpha: 1)
    rounded(NSRect(x: 64, y: 64, width: 896, height: 896), radius: 196, color: navy)

    // Diagonal aerial with a rounded cap, independent of any system glyph.
    cream.setStroke()
    let aerial = NSBezierPath()
    aerial.move(to: NSPoint(x: 335, y: 665))
    aerial.line(to: NSPoint(x: 658, y: 794))
    aerial.lineWidth = 32
    aerial.lineCapStyle = .round
    aerial.stroke()
    rounded(NSRect(x: 218, y: 280, width: 588, height: 404), radius: 76, color: cream)

    // Speaker grille: four broad slots stay legible at Finder's small sizes.
    for y in [397, 447, 497, 547] {
        rounded(NSRect(x: 286, y: y, width: 196, height: 20), radius: 10, color: navy)
    }
    rounded(NSRect(x: 542, y: 382, width: 196, height: 200), radius: 32, color: navy)
    for (x, y, height) in [(586, 455, 54), (628, 423, 118), (670, 445, 74)] {
        rounded(NSRect(x: x, y: y, width: 24, height: height), radius: 12, color: cream)
    }
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let data = try draw(size: points * scale)
        try data.write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
        if points == 512 && scale == 2 {
            try data.write(to: root.appendingPathComponent("Resources/AppIcon.png"))
        }
    }
}
