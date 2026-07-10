#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: create_dmg_background.swift <output.png>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 720, height: 460)
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )
else {
    FileHandle.standardError.write(Data("error: failed to create DMG background bitmap\n".utf8))
    exit(1)
}
bitmap.size = size

func centeredRect(for text: NSString, attributes: [NSAttributedString.Key: Any], y: CGFloat) -> NSRect {
    let textSize = text.size(withAttributes: attributes)
    return NSRect(
        x: (size.width - textSize.width) / 2,
        y: y,
        width: textSize.width,
        height: textSize.height
    )
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

let bounds = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.957, green: 0.962, blue: 0.946, alpha: 1).setFill()
bounds.fill()

let backdrop = NSGradient(colors: [
    NSColor(calibratedRed: 0.998, green: 0.999, blue: 0.992, alpha: 1),
    NSColor(calibratedRed: 0.937, green: 0.944, blue: 0.922, alpha: 1),
])
backdrop?.draw(in: bounds, angle: -90)

let topGlow = NSGradient(colors: [
    NSColor(calibratedWhite: 1, alpha: 0.72),
    NSColor(calibratedWhite: 1, alpha: 0),
])
topGlow?.draw(in: NSRect(x: 0, y: 250, width: size.width, height: 210), angle: -90)

let panel = NSBezierPath(roundedRect: bounds.insetBy(dx: 24, dy: 26), xRadius: 30, yRadius: 30)
let panelShadow = NSShadow()
panelShadow.shadowBlurRadius = 22
panelShadow.shadowOffset = NSSize(width: 0, height: -8)
panelShadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.08)
NSGraphicsContext.saveGraphicsState()
panelShadow.set()
NSColor(calibratedWhite: 1, alpha: 0.42).setFill()
panel.fill()
NSGraphicsContext.restoreGraphicsState()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 0.35, alpha: 1),
]
"Install Assist".draw(in: centeredRect(for: "Install Assist", attributes: titleAttributes, y: 378), withAttributes: titleAttributes)
"Drag the app into Applications".draw(
    in: centeredRect(for: "Drag the app into Applications", attributes: subtitleAttributes, y: 356),
    withAttributes: subtitleAttributes
)

let arrowColor = NSColor(calibratedRed: 0.36, green: 0.40, blue: 0.34, alpha: 0.50)
arrowColor.setStroke()

let arrowStart = NSPoint(x: 318, y: 218)
let arrowTip = NSPoint(x: 402, y: 218)
let arrowHeadTop = NSPoint(x: 380, y: 233)
let arrowHeadBottom = NSPoint(x: 380, y: 203)
let arrow = NSBezierPath()
arrow.move(to: arrowStart)
arrow.line(to: arrowTip)
arrow.move(to: arrowHeadTop)
arrow.line(to: arrowTip)
arrow.line(to: arrowHeadBottom)
arrow.lineWidth = 5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.stroke()

NSColor(calibratedWhite: 1, alpha: 0.56).setStroke()
let frame = NSBezierPath(roundedRect: bounds.insetBy(dx: 24, dy: 26), xRadius: 30, yRadius: 30)
frame.lineWidth = 1
frame.stroke()

NSGraphicsContext.restoreGraphicsState()

guard
    let png = bitmap.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("error: failed to render DMG background\n".utf8))
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
