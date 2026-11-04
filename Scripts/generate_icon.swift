#!/usr/bin/env swift
import AppKit

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func drawIcon() {
    let tile = rounded(100, 100, 824, 824, 185)
    NSGradient(colors: [rgb(92, 124, 255), rgb(88, 56, 214)])!.draw(in: tile, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    NSGradient(colors: [rgb(255, 255, 255, 0.20), rgb(255, 255, 255, 0)])!
        .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(25, 12, 90, 0.40)
    shadow.shadowBlurRadius = 34 * NSGraphicsContext.current!.cgContext.ctm.a
    shadow.shadowOffset = NSSize(width: 0, height: -16 * NSGraphicsContext.current!.cgContext.ctm.a)
    shadow.set()
    rgb(255, 255, 255).setFill()
    rounded(262, 196, 500, 600, 62).fill()
    NSGraphicsContext.restoreGraphicsState()

    rgb(92, 96, 214, 0.34).setFill()
    rounded(342, 556, 340, 40, 20).fill()
    rounded(342, 456, 340, 40, 20).fill()
    rounded(342, 356, 214, 40, 20).fill()

    let clip = rounded(372, 690, 280, 150, 44)
    NSGradient(colors: [rgb(60, 58, 112), rgb(36, 32, 78)])!.draw(in: clip, angle: -90)
    rgb(255, 255, 255, 0.95).setFill()
    NSBezierPath(ovalIn: NSRect(x: 484, y: 770, width: 56, height: 40)).fill()
}

let outputDir = URL(fileURLWithPath: "Assets.xcassets/AppIcon.appiconset")
var images: [[String: String]] = []

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let factor = CGFloat(pixels) / 1024
        context.cgContext.scaleBy(x: factor, y: factor)
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()

        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try! rep.representation(using: .png, properties: [:])!.write(to: outputDir.appendingPathComponent(name))
        images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: outputDir.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(outputDir.path)")
