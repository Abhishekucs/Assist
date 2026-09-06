#!/usr/bin/env swift

import AppKit

private let outputDimension = 256
private let cropInsetFraction = 0.19

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: generate_menu_bar_icon.swift <source.png> <output.png>\n", stderr)
    exit(64)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to load source image at \(sourceURL.path)\n", stderr)
    exit(66)
}

let sourceSide = min(sourceImage.size.width, sourceImage.size.height)
let cropInset = sourceSide * cropInsetFraction
let cropRect = NSRect(
    x: (sourceImage.size.width - sourceSide) / 2 + cropInset,
    y: (sourceImage.size.height - sourceSide) / 2 + cropInset,
    width: sourceSide - (cropInset * 2),
    height: sourceSide - (cropInset * 2)
)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: outputDimension,
    pixelsHigh: outputDimension,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to allocate output bitmap\n", stderr)
    exit(70)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: outputDimension, height: outputDimension).fill()
sourceImage.draw(
    in: NSRect(x: 0, y: 0, width: outputDimension, height: outputDimension),
    from: cropRect,
    operation: .sourceOver,
    fraction: 1,
    respectFlipped: false,
    hints: [.interpolation: NSImageInterpolation.high]
)
NSGraphicsContext.restoreGraphicsState()

guard let pixels = bitmap.bitmapData, bitmap.samplesPerPixel == 4 else {
    fputs("Unable to access output pixels\n", stderr)
    exit(70)
}

for y in 0 ..< outputDimension {
    for x in 0 ..< outputDimension {
        let offset = (y * bitmap.bytesPerRow) + (x * bitmap.samplesPerPixel)
        let red = CGFloat(pixels[offset]) / 255
        let green = CGFloat(pixels[offset + 1]) / 255
        let blue = CGFloat(pixels[offset + 2]) / 255
        let sourceAlpha = CGFloat(pixels[offset + 3]) / 255
        let brightest = max(red, green, blue)
        let darkest = min(red, green, blue)
        let chroma = brightest - darkest
        let brightnessSignal = (brightest - 0.16) / 0.14
        let colorSignal = (chroma - 0.10) / 0.10
        let signal = max(brightnessSignal, colorSignal)
        let alpha = min(max(signal, 0), 1)

        pixels[offset] = 255
        pixels[offset + 1] = 255
        pixels[offset + 2] = 255
        pixels[offset + 3] = UInt8((alpha * sourceAlpha * 255).rounded())
    }
}

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode menu bar icon\n", stderr)
    exit(70)
}

do {
    try png.write(to: outputURL, options: .atomic)
} catch {
    fputs("Unable to write \(outputURL.path): \(error)\n", stderr)
    exit(73)
}
