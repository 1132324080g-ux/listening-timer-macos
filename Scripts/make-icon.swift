import AppKit
import Foundation
import SwiftUI

guard CommandLine.arguments.count == 3 else {
    fputs(
        "Usage: make-icon.swift <source.png> <output.iconset>\n",
        stderr
    )
    exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Could not read source icon: \(sourceURL.path)\n", stderr)
    exit(1)
}
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
    NSColor.clear.setFill()
    rect.fill()

    let artworkInset = CGFloat(size) * (100.0 / 1024.0)
    let artworkRect = rect.insetBy(
        dx: artworkInset,
        dy: artworkInset
    )
    let cornerRadius = artworkRect.width * (185.4 / 824.0)
    let artworkPath = NSBezierPath(
        cgPath: Path(
            roundedRect: artworkRect,
            cornerRadius: cornerRadius,
            style: .continuous
        ).cgPath
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = max(0.5, CGFloat(size) * 0.022)
    shadow.shadowOffset = NSSize(
        width: 0,
        height: -max(0.25, CGFloat(size) * 0.006)
    )
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.black.setFill()
    artworkPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    artworkPath.addClip()
    sourceImage.draw(
        in: artworkRect,
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )

    let rimInset = max(0.35, CGFloat(size) * 0.001)
    let rimPath = NSBezierPath(
        cgPath: Path(
            roundedRect: artworkRect.insetBy(
                dx: rimInset,
                dy: rimInset
            ),
            cornerRadius: max(0, cornerRadius - rimInset),
            style: .continuous
        ).cgPath
    )
    NSColor.white.withAlphaComponent(0.10).setStroke()
    rimPath.lineWidth = max(0.7, CGFloat(size) * 0.0015)
    rimPath.stroke()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fputs("Could not encode icon PNG\n", stderr)
        exit(1)
    }
    try data.write(to: output.appendingPathComponent(variant.name))
}
