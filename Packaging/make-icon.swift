#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// Renders Packaging/AppIcon.icns — a clipboard with a document tree on it.
// Run: swift Packaging/make-icon.swift

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let packagingDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iconset = packagingDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(size: Int) -> Data {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    // Rounded-rect background with a blue gradient.
    let inset = s * 0.06
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let bg = NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22)
    ctx.saveGState()
    bg.addClip()
    let gradient = NSGradient(
        colors: [NSColor(srgbRed: 0.29, green: 0.53, blue: 0.96, alpha: 1),
                 NSColor(srgbRed: 0.16, green: 0.33, blue: 0.78, alpha: 1)]
    )!
    gradient.draw(in: rect, angle: -90)
    ctx.restoreGState()

    // Clipboard sheet.
    let sheetW = rect.width * 0.56
    let sheetH = rect.height * 0.64
    let sheet = CGRect(
        x: rect.midX - sheetW / 2,
        y: rect.midY - sheetH / 2 - rect.height * 0.03,
        width: sheetW, height: sheetH
    )
    NSColor.white.setFill()
    NSBezierPath(roundedRect: sheet, xRadius: s * 0.04, yRadius: s * 0.04).fill()

    // Clip at the top.
    let clipW = sheetW * 0.44
    let clipH = sheetH * 0.14
    let clip = CGRect(
        x: sheet.midX - clipW / 2, y: sheet.maxY - clipH * 0.55,
        width: clipW, height: clipH
    )
    NSColor(srgbRed: 0.82, green: 0.86, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(roundedRect: clip, xRadius: s * 0.022, yRadius: s * 0.022).fill()

    // Tree rows: indent pattern suggesting a directory listing.
    let indents: [CGFloat] = [0, 0.14, 0.14, 0.28, 0.14]
    let widths: [CGFloat] = [0.62, 0.48, 0.52, 0.38, 0.44]
    let rowH = sheetH * 0.070
    let gap = sheetH * 0.055
    var y = sheet.maxY - sheetH * 0.30
    for (indent, width) in zip(indents, widths) {
        let row = CGRect(
            x: sheet.minX + sheetW * (0.16 + indent),
            y: y, width: sheetW * width, height: rowH
        )
        NSColor(srgbRed: 0.35, green: 0.45, blue: 0.62, alpha: 1).setFill()
        NSBezierPath(roundedRect: row, xRadius: rowH / 2, yRadius: rowH / 2).fill()
        y -= rowH + gap
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("failed to render \(size)")
    }
    return png
}

for size in sizes {
    let data = draw(size: size)
    try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    // Retina variant is the same pixel dimensions at half the point size.
    if size >= 32, sizes.contains(size / 2) {
        try data.write(to: iconset.appendingPathComponent("icon_\(size / 2)x\(size / 2)@2x.png"))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "-c", "icns", iconset.path,
    "-o", packagingDir.appendingPathComponent("AppIcon.icns").path,
]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("wrote \(packagingDir.appendingPathComponent("AppIcon.icns").path)")
