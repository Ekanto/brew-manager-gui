// Generates Resources/AppIcon.icns for BrewManager.
//
// Run with: swift Scripts/make-icon.swift <output-directory>
//
// The icon is drawn at 1024pt using the same amber palette as Theme.swift so
// the Dock icon matches the app's interior.

import AppKit
import Foundation

let arguments = CommandLine.arguments
let outputDirectory = arguments.count > 1
    ? URL(fileURLWithPath: arguments[1])
    : URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources")

let canvasSize: CGFloat = 1024

func makeIconImage() -> NSImage {
    let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    // Apple's macOS icon grid: the rounded square is inset from the canvas.
    let inset: CGFloat = 100
    let plateRect = CGRect(
        x: inset,
        y: inset,
        width: canvasSize - inset * 2,
        height: canvasSize - inset * 2
    )
    let cornerRadius: CGFloat = 185

    let plate = NSBezierPath(roundedRect: plateRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Drop shadow so the icon reads on both light and dark Dock backgrounds.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -12),
        blur: 28,
        color: NSColor.black.withAlphaComponent(0.32).cgColor
    )
    NSColor.black.setFill()
    plate.fill()
    context.restoreGState()

    // Amber gradient body, matching Theme.Palette.amber -> amberDeep.
    context.saveGState()
    plate.addClip()

    let amber = NSColor(srgbRed: 0.98, green: 0.72, blue: 0.22, alpha: 1)
    let amberDeep = NSColor(srgbRed: 0.90, green: 0.42, blue: 0.08, alpha: 1)
    let gradient = NSGradient(starting: amber, ending: amberDeep)
    gradient?.draw(in: plateRect, angle: -60)

    // Glossy highlight across the upper third.
    let highlight = NSGradient(
        starting: NSColor.white.withAlphaComponent(0.34),
        ending: NSColor.white.withAlphaComponent(0.0)
    )
    let highlightRect = CGRect(
        x: plateRect.minX,
        y: plateRect.midY,
        width: plateRect.width,
        height: plateRect.height / 2
    )
    highlight?.draw(in: highlightRect, angle: -90)

    context.restoreGState()

    // Inner rim for definition.
    context.saveGState()
    NSColor.white.withAlphaComponent(0.28).setStroke()
    let rim = NSBezierPath(
        roundedRect: plateRect.insetBy(dx: 5, dy: 5),
        xRadius: cornerRadius - 5,
        yRadius: cornerRadius - 5
    )
    rim.lineWidth = 8
    rim.stroke()
    context.restoreGState()

    drawGlyph(in: plateRect)

    image.unlockFocus()
    return image
}

/// Draws a beer mug, echoing Homebrew's own branding.
func drawGlyph(in plateRect: CGRect) {
    let symbolNames = ["mug.fill", "cup.and.saucer.fill", "shippingbox.fill"]

    var symbol: NSImage?
    for name in symbolNames {
        if let candidate = NSImage(systemSymbolName: name, accessibilityDescription: "Brew Manager") {
            symbol = candidate
            break
        }
    }

    guard let symbol else {
        drawFallbackGlyph(in: plateRect)
        return
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: 470, weight: .semibold)
    let configured = symbol.withSymbolConfiguration(configuration) ?? symbol

    let symbolSize = configured.size
    let targetRect = CGRect(
        x: plateRect.midX - symbolSize.width / 2,
        y: plateRect.midY - symbolSize.height / 2,
        width: symbolSize.width,
        height: symbolSize.height
    )

    guard let context = NSGraphicsContext.current?.cgContext else { return }

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -8),
        blur: 20,
        color: NSColor.black.withAlphaComponent(0.28).cgColor
    )

    // The tint must happen inside a transparency layer. Compositing `sourceAtop`
    // straight onto the plate would fill the whole rect, because the plate is
    // opaque everywhere; inside a layer the destination starts empty, so only
    // the symbol's own pixels are tinted.
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    configured.draw(in: targetRect)
    context.setBlendMode(.sourceAtop)
    NSColor.white.setFill()
    targetRect.fill()
    context.endTransparencyLayer()

    context.restoreGState()
}

func drawFallbackGlyph(in plateRect: CGRect) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 460, weight: .bold),
        .foregroundColor: NSColor.white
    ]
    let text = NSAttributedString(string: "B", attributes: attributes)
    let textSize = text.size()
    text.draw(
        at: NSPoint(
            x: plateRect.midX - textSize.width / 2,
            y: plateRect.midY - textSize.height / 2
        )
    )
}

func pngData(from image: NSImage, size: CGFloat) -> Data? {
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return nil
    }

    representation.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    return representation.representation(using: .png, properties: [:])
}

let iconImage = makeIconImage()

let fileManager = FileManager.default
try? fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconsetURL = outputDirectory.appendingPathComponent("AppIcon.iconset")
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

// (file name, pixel size) pairs required by iconutil.
let variants: [(String, CGFloat)] = [
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

for (name, size) in variants {
    guard let data = pngData(from: iconImage, size: size) else {
        FileHandle.standardError.write(Data("error: could not render \(name)\n".utf8))
        exit(1)
    }
    try data.write(to: iconsetURL.appendingPathComponent(name))
}

// Keep a flat 1024pt PNG around for the DMG volume icon and any docs.
if let data = pngData(from: iconImage, size: 1024) {
    try data.write(to: outputDirectory.appendingPathComponent("AppIcon.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = [
    "--convert", "icns",
    "--output", outputDirectory.appendingPathComponent("AppIcon.icns").path,
    iconsetURL.path
]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("error: iconutil failed\n".utf8))
    exit(iconutil.terminationStatus)
}

try? fileManager.removeItem(at: iconsetURL)

print("Wrote \(outputDirectory.appendingPathComponent("AppIcon.icns").path)")
