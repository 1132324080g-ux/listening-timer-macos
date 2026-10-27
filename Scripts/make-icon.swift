import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: make-icon.swift <output.iconset>\n", stderr)
    exit(64)
}

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: output,
    withIntermediateDirectories: true
)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let size = variant.pixels
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else {
        fputs("Could not allocate icon bitmap\n", stderr)
        exit(1)
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        bitmapImageRep: bitmap
    )

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let inset = CGFloat(size) * 0.055
    let plate = rect.insetBy(dx: inset, dy: inset)
    let radius = CGFloat(size) * 0.225
    let path = NSBezierPath(
        roundedRect: plate,
        xRadius: radius,
        yRadius: radius
    )

    NSColor.clear.setFill()
    rect.fill()

    path.addClip()
    let background = NSGradient(
        colorsAndLocations:
            (
                NSColor(
                    calibratedRed: 0.08,
                    green: 0.23,
                    blue: 0.22,
                    alpha: 1
                ),
                0.0
            ),
            (
                NSColor(
                    calibratedRed: 0.12,
                    green: 0.55,
                    blue: 0.49,
                    alpha: 1
                ),
                0.52
            ),
            (
                NSColor(
                    calibratedRed: 0.43,
                    green: 0.76,
                    blue: 0.68,
                    alpha: 1
                ),
                1.0
            )
    )!
    background.draw(in: plate, angle: -52)

    NSColor(
        calibratedRed: 0.94,
        green: 0.58,
        blue: 0.42,
        alpha: 0.82
    ).setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: plate.maxX - CGFloat(size) * 0.38,
            y: plate.minY + CGFloat(size) * 0.05,
            width: CGFloat(size) * 0.42,
            height: CGFloat(size) * 0.42
        )
    ).fill()

    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(
        ovalIn: NSRect(
            x: plate.minX - CGFloat(size) * 0.18,
            y: plate.maxY - CGFloat(size) * 0.38,
            width: CGFloat(size) * 0.68,
            height: CGFloat(size) * 0.68
        )
    ).fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(
        bitmapImageRep: bitmap
    )

    let symbolSize = CGFloat(size) * 0.46
    let config = NSImage.SymbolConfiguration(
        pointSize: symbolSize,
        weight: .semibold
    )
    if let symbol = NSImage(
        systemSymbolName: "headphones",
        accessibilityDescription: nil
    )?.withSymbolConfiguration(config) {
        symbol.isTemplate = true
        NSColor.white.set()
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbol.size.width) / 2,
            y: (CGFloat(size) - symbol.size.height) / 2,
            width: symbol.size.width,
            height: symbol.size.height
        )
        symbol.draw(
            in: symbolRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Could not encode icon PNG\n", stderr)
        exit(1)
    }
    try data.write(to: output.appendingPathComponent(variant.name))
}
