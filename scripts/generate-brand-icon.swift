import AppKit
import Foundation

// Original vector artwork for Punto. Generates the iconset used by the build.
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
let entries = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
let ink = NSColor(red: 0.095, green: 0.10, blue: 0.12, alpha: 1)
for (points, scale) in entries {
    let pixels = points * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let tile = NSBezierPath(roundedRect: NSRect(x: 94, y: 94, width: 836, height: 836), xRadius: 184, yRadius: 184)
    let shadow = NSShadow(); shadow.shadowColor = .black.withAlphaComponent(0.25); shadow.shadowBlurRadius = 30; shadow.shadowOffset = NSSize(width: 0, height: -12)
    NSGraphicsContext.saveGraphicsState(); shadow.set(); ink.setFill(); tile.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.20, green: 0.21, blue: 0.25, alpha: 1), ending: ink)!.draw(in: tile, angle: -70)
    NSColor.white.withAlphaComponent(0.08).setStroke(); tile.lineWidth = 2; tile.stroke()

    let controller = NSBezierPath()
    controller.move(to: NSPoint(x: 362, y: 674))
    controller.curve(to: NSPoint(x: 284, y: 610), controlPoint1: NSPoint(x: 326, y: 674), controlPoint2: NSPoint(x: 294, y: 647))
    controller.curve(to: NSPoint(x: 214, y: 355), controlPoint1: NSPoint(x: 259, y: 536), controlPoint2: NSPoint(x: 221, y: 421))
    controller.curve(to: NSPoint(x: 340, y: 319), controlPoint1: NSPoint(x: 200, y: 279), controlPoint2: NSPoint(x: 281, y: 266))
    controller.line(to: NSPoint(x: 427, y: 403))
    controller.line(to: NSPoint(x: 597, y: 403))
    controller.line(to: NSPoint(x: 684, y: 319))
    controller.curve(to: NSPoint(x: 810, y: 355), controlPoint1: NSPoint(x: 743, y: 266), controlPoint2: NSPoint(x: 824, y: 279))
    controller.curve(to: NSPoint(x: 740, y: 610), controlPoint1: NSPoint(x: 803, y: 421), controlPoint2: NSPoint(x: 765, y: 536))
    controller.curve(to: NSPoint(x: 662, y: 674), controlPoint1: NSPoint(x: 730, y: 647), controlPoint2: NSPoint(x: 698, y: 674))
    controller.close()
    NSGraphicsContext.saveGraphicsState()
    let bodyShadow = NSShadow(); bodyShadow.shadowColor = .black.withAlphaComponent(0.28); bodyShadow.shadowBlurRadius = 18; bodyShadow.shadowOffset = NSSize(width: 0, height: -8)
    bodyShadow.set(); NSColor.white.setFill(); controller.fill(); NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(white: 1, alpha: 1), ending: NSColor(white: 0.83, alpha: 1))!.draw(in: controller, angle: -90)

    ink.setFill()
    NSBezierPath(roundedRect: NSRect(x: 324, y: 478, width: 47, height: 143), xRadius: 10, yRadius: 10).fill()
    NSBezierPath(roundedRect: NSRect(x: 276, y: 526, width: 143, height: 47), xRadius: 10, yRadius: 10).fill()
    NSBezierPath(ovalIn: NSRect(x: 440, y: 448, width: 55, height: 55)).fill()
    NSColor(white: 0.36, alpha: 1).setFill(); NSBezierPath(ovalIn: NSRect(x: 453, y: 461, width: 29, height: 29)).fill()
    NSColor(white: 0.55, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 462, y: 604, width: 47, height: 12), xRadius: 6, yRadius: 6).fill()

    let cursor = NSBezierPath()
    cursor.move(to: NSPoint(x: 586, y: 744))
    cursor.line(to: NSPoint(x: 586, y: 440))
    cursor.line(to: NSPoint(x: 652, y: 500))
    cursor.line(to: NSPoint(x: 711, y: 397))
    cursor.line(to: NSPoint(x: 772, y: 432))
    cursor.line(to: NSPoint(x: 713, y: 535))
    cursor.line(to: NSPoint(x: 806, y: 548))
    cursor.close()
    ink.setStroke(); cursor.lineWidth = 20; cursor.lineJoinStyle = .round; cursor.stroke()
    NSGradient(starting: NSColor(red: 1, green: 0.43, blue: 0.43, alpha: 1), ending: NSColor(red: 0.89, green: 0.22, blue: 0.31, alpha: 1))!.draw(in: cursor, angle: -70)
    NSGraphicsContext.restoreGraphicsState()
    let suffix = scale == 2 ? "@2x" : ""
    let url = URL(fileURLWithPath: destination).appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
