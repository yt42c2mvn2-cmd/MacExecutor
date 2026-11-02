import AppKit
import CoreGraphics
import Foundation

// Generates an original vector version of the Rebilium R/glass icon
// directly into Xcode's macOS app-icon asset catalog.
guard CommandLine.arguments.count >= 2 else {
    fatalError("Expected repository/project directory")
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let folder = root.appendingPathComponent(
    "MacExecutor/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let dark = NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.24, alpha: 1)
let violet = NSColor(calibratedRed: 0.70, green: 0.54, blue: 0.97, alpha: 1)
let blue = NSColor(calibratedRed: 0.65, green: 0.86, blue: 1.0, alpha: 1)

func drawIcon(in context: CGContext) {
    context.saveGState()
    defer { context.restoreGState() }

    let rect = CGRect(x: 45, y: 45, width: 934, height: 934)
    let frame = CGPath(roundedRect: rect, cornerWidth: 220, cornerHeight: 220, transform: nil)
    context.addPath(frame)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            NSColor(calibratedRed: 0.81, green: 0.72, blue: 0.99, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.92, green: 0.92, blue: 1, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.73, green: 0.89, blue: 1, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 0.52, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 85, y: 170),
        end: CGPoint(x: 905, y: 920),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    // Translucent liquid-glass wave in the lower-left.
    let bottomWave = CGMutablePath()
    bottomWave.move(to: CGPoint(x: 50, y: 320))
    bottomWave.addCurve(to: CGPoint(x: 975, y: 85),
                        control1: CGPoint(x: 285, y: 310),
                        control2: CGPoint(x: 390, y: -45))
    bottomWave.addLine(to: CGPoint(x: 50, y: 45))
    bottomWave.closeSubpath()
    context.addPath(bottomWave)
    context.setFillColor(violet.withAlphaComponent(0.27).cgColor)
    context.fillPath()

    // Clear-blue sweeping reflection on the upper-right.
    let topWave = CGMutablePath()
    topWave.move(to: CGPoint(x: 175, y: 962))
    topWave.addCurve(to: CGPoint(x: 980, y: 585),
                     control1: CGPoint(x: 575, y: 1060),
                     control2: CGPoint(x: 755, y: 595))
    topWave.addLine(to: CGPoint(x: 980, y: 980))
    topWave.closeSubpath()
    context.addPath(topWave)
    context.setFillColor(blue.withAlphaComponent(0.36).cgColor)
    context.fillPath()

    // Thin frosted edge and upper sheen.
    context.addPath(frame)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.78).cgColor)
    context.setLineWidth(23)
    context.strokePath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 2, height: -2), blur: 9,
                      color: NSColor.black.withAlphaComponent(0.16).cgColor)

    // Thick geometric capital R, connected to its slanted leg.
    let letter = CGMutablePath()
    letter.move(to: CGPoint(x: 287, y: 253))
    letter.addLine(to: CGPoint(x: 287, y: 741))
    letter.addQuadCurve(to: CGPoint(x: 322, y: 782),
                        control: CGPoint(x: 287, y: 782))
    letter.addLine(to: CGPoint(x: 600, y: 782))
    letter.addCurve(to: CGPoint(x: 759, y: 606),
                    control1: CGPoint(x: 724, y: 778),
                    control2: CGPoint(x: 771, y: 720))
    letter.addCurve(to: CGPoint(x: 619, y: 458),
                    control1: CGPoint(x: 759, y: 519),
                    control2: CGPoint(x: 697, y: 458))
    context.addPath(letter)
    context.setStrokeColor(dark.cgColor)
    context.setLineWidth(33)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.strokePath()

    let lowerStem = CGMutablePath()
    lowerStem.move(to: CGPoint(x: 287, y: 255))
    lowerStem.addLine(to: CGPoint(x: 411, y: 255))
    lowerStem.addLine(to: CGPoint(x: 411, y: 432))
    context.addPath(lowerStem)
    context.setLineWidth(33)
    context.strokePath()

    let leg = CGMutablePath()
    leg.move(to: CGPoint(x: 586, y: 460))
    leg.addLine(to: CGPoint(x: 754, y: 260))
    leg.addLine(to: CGPoint(x: 605, y: 260))
    leg.addLine(to: CGPoint(x: 487, y: 390))
    context.addPath(leg)
    context.strokePath()

    // The skewed square frame passing diagonally through the R.
    let square = CGMutablePath()
    square.move(to: CGPoint(x: 318, y: 484))
    square.addLine(to: CGPoint(x: 410, y: 670))
    square.addLine(to: CGPoint(x: 633, y: 713))
    square.addLine(to: CGPoint(x: 677, y: 657))
    square.addLine(to: CGPoint(x: 544, y: 366))
    square.closeSubpath()
    context.addPath(square)
    context.setLineWidth(33)
    context.strokePath()

    let center = CGPath(
        roundedRect: CGRect(x: 437, y: 455, width: 89, height: 89),
        cornerWidth: 10,
        cornerHeight: 10,
        transform: nil
    )
    context.addPath(center)
    context.setLineWidth(25)
    context.strokePath()

    context.restoreGState()
}

try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

for size in sizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Failed to create \(size)x\(size) icon bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    graphics.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: graphics.cgContext)
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to write icon PNG at size \(size)")
    }
    try png.write(to: folder.appendingPathComponent("rebilium_\(size).png"), options: .atomic)
}

print("Generated Rebilium app icons (16–1024 pixels)")
