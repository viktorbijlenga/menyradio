// Export the macOS system symbols used in the README image, not app icons.
import AppKit
import Foundation
let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs/images")
for name in ["radio.fill", "wifi", "battery.100", "speaker.wave.2.fill"] {
    let size = NSSize(width: 24, height: 20)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 72, pixelsHigh: 60,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: 3, y: 3)
    let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.black]))
    let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    let ratio = min(size.width / symbol.size.width, size.height / symbol.size.height)
    let dimensions = NSSize(width: symbol.size.width * ratio, height: symbol.size.height * ratio)
    symbol.draw(in: NSRect(x: (size.width-dimensions.width)/2, y: (size.height-dimensions.height)/2,
                          width: dimensions.width, height: dimensions.height))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("\(name).png"))
}
