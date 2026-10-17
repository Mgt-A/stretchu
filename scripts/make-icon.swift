#!/usr/bin/env swift
// Generates Resources/AppIcon.icns: a 25-minute timer ring with a gold lightning bolt on a dark
// blue rounded square. Pure vector drawing, no sprite. Usage: swift scripts/make-icon.swift
import AppKit
import Foundation

let repo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func color(_ hex: UInt32) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let background = color(0x011C6B)
let track = color(0x2946C4)
let progress = color(0xE9E6DE)
let bolt = color(0xB4811F)

/// The bolt, in the 24 × 24 drawing space.
let boltPoints: [CGPoint] = [
    CGPoint(x: 14, y: 3.5), CGPoint(x: 6.6, y: 13.2), CGPoint(x: 11.4, y: 13.2),
    CGPoint(x: 10, y: 20.5), CGPoint(x: 17.4, y: 10.8), CGPoint(x: 12.6, y: 10.8),
]

func render(size: Int) -> Data {
    let t = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Top-left origin, y down, like the design file.
    ctx.translateBy(x: 0, y: t)
    ctx.scaleBy(x: 1, y: -1)

    // macOS icon grid: centered 824/1024 square, rounded corners (~22 %).
    let side = t * 824 / 1024
    let square = CGRect(x: (t - side) / 2, y: (t - side) / 2, width: side, height: side)
    ctx.setFillColor(background)
    ctx.addPath(CGPath(roundedRect: square, cornerWidth: side * 0.225, cornerHeight: side * 0.225, transform: nil))
    ctx.fillPath()

    // The 24 × 24 drawing fills 78 % of the square, centered.
    let art = side * 0.78
    ctx.translateBy(x: (t - art) / 2, y: (t - art) / 2)
    ctx.scaleBy(x: art / 24, y: art / 24)
    let center = CGPoint(x: 12, y: 12)

    ctx.setLineWidth(1.6)
    ctx.setStrokeColor(track)
    ctx.addArc(center: center, radius: 10.2, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    // 240° from the top, clockwise on screen, square ends.
    ctx.setLineCap(.butt)
    ctx.setStrokeColor(progress)
    ctx.addArc(center: center, radius: 10.2, startAngle: -.pi / 2, endAngle: .pi * 150 / 180, clockwise: false)
    ctx.strokePath()

    // Bolt, scaled to 78 % around the center.
    ctx.translateBy(x: 12, y: 12)
    ctx.scaleBy(x: 0.78, y: 0.78)
    ctx.translateBy(x: -12, y: -12)
    ctx.setFillColor(bolt)
    ctx.addLines(between: boltPoints)
    ctx.closePath()
    ctx.fillPath()

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let output = repo.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try p.run(); p.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print(p.terminationStatus == 0 ? "Resources/AppIcon.icns written" : "iconutil failed")
