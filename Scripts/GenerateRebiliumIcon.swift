import AppKit
import CoreGraphics
import Foundation

/// Draw a distinctive gradient R with a geometric square inserted into its
/// middle. Both icon appearances share precisely the same vector geometry.
enum IconAppearance: String, CaseIterable {
    case light, dark

    var foreground: [CGColor] {
        switch self {
        case .light:
            return [
                NSColor(calibratedRed: 1.00, green: 0.99, blue: 1.00, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.84, green: 0.89, blue: 1.00, alpha: 1).cgColor
            ]
        case .dark:
            return [
                NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.85, green: 0.92, blue: 1.00, alpha: 1).cgColor
            ]
        }
    }

    var background: [CGColor] {
        switch self {
        case .light:
            return [
                NSColor(calibratedRed: 0.62, green: 0.20, blue: 0.98, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.23, green: 0.19, blue: 0.88, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.08, green: 0.53, blue: 1.00, alpha: 1).cgColor
            ]
        case .dark:
            return [
                NSColor(calibratedRed: 0.19, green: 0.20, blue: 0.24, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.055, green: 0.062, blue: 0.085, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.095, green: 0.12, blue: 0.17, alpha: 1).cgColor
            ]
        }
    }

    var accent: NSColor {
        switch self {
        case .light: NSColor(calibratedRed: 0.10, green: 0.70, blue: 1.00, alpha: 1)
        case .dark: NSColor(calibratedRed: 0.34, green: 0.30, blue: 1.00, alpha: 1)
        }
    }
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: colors.count == 3 ? [0, 0.48, 1] : [0, 1]
    )!
}

func drawIcon(_ context: CGContext, appearance: IconAppearance) {
    context.saveGState()
    defer { context.restoreGState() }

    let base = CGRect(x: 44, y: 44, width: 936, height: 936)
    let rounded = CGPath(roundedRect: base, cornerWidth: 214, cornerHeight: 214, transform: nil)
    context.addPath(rounded)
    context.clip()

    let bg = gradient(appearance.background)
    let bgStart = CGPoint(x: 50, y: 950)
    let bgEnd = CGPoint(x: 975, y: 70)
    context.drawLinearGradient(bg, start: bgStart, end: bgEnd, options: [])

    // Vibrant but localized purple-blue light; deep graphite remains the
    // dominant tone in the dark icon rather than becoming pastel gray.
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: 60, y: 330))
    wave.addCurve(to: CGPoint(x: 980, y: 150),
                  control1: CGPoint(x: 400, y: 390),
                  control2: CGPoint(x: 420, y: 0))
    wave.addLine(to: CGPoint(x: 980, y: 45))
    wave.addLine(to: CGPoint(x: 45, y: 45))
    wave.closeSubpath()
    context.addPath(wave)
    context.setFillColor(appearance.accent.withAlphaComponent(
        appearance == .light ? 0.47 : 0.35
    ).cgColor)
    context.fillPath()

    let upperGlow = CGMutablePath()
    upperGlow.move(to: CGPoint(x: 80, y: 860))
    upperGlow.addCurve(to: CGPoint(x: 980, y: 590),
                       control1: CGPoint(x: 580, y: 1060),
                       control2: CGPoint(x: 770, y: 585))
    upperGlow.addLine(to: CGPoint(x: 980, y: 975))
    upperGlow.closeSubpath()
    context.addPath(upperGlow)
    context.setFillColor(NSColor.white.withAlphaComponent(
        appearance == .light ? 0.10 : 0.025
    ).cgColor)
    context.fillPath()

    context.addPath(rounded)
    context.setStrokeColor(NSColor.white.withAlphaComponent(
        appearance == .light ? 0.47 : 0.15
    ).cgColor)
    context.setLineWidth(17)
    context.strokePath()

    // Base R: a substantial monogram, not a decorative frame masquerading as R.
    // A single stroked path forms the stem, bowl and diagonal leg.
    let letter = CGMutablePath()
    letter.move(to: CGPoint(x: 300, y: 258))
    letter.addLine(to: CGPoint(x: 300, y: 756))
    letter.move(to: CGPoint(x: 305, y: 756))
    letter.addLine(to: CGPoint(x: 553, y: 756))
    letter.addCurve(to: CGPoint(x: 710, y: 607),
                    control1: CGPoint(x: 662, y: 756),
                    control2: CGPoint(x: 712, y: 701))
    letter.addCurve(to: CGPoint(x: 547, y: 505),
                    control1: CGPoint(x: 710, y: 531),
                    control2: CGPoint(x: 663, y: 505))
    letter.addLine(to: CGPoint(x: 305, y: 505))
    letter.move(to: CGPoint(x: 515, y: 503))
    letter.addLine(to: CGPoint(x: 744, y: 251))

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 22,
                      color: NSColor.black.withAlphaComponent(0.30).cgColor)
    context.addPath(letter)
    context.setLineWidth(116)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.replacePathWithStrokedPath()
    context.clip()
    context.drawLinearGradient(gradient(appearance.foreground),
                               start: CGPoint(x: 280, y: 810),
                               end: CGPoint(x: 740, y: 240),
                               options: [])
    context.restoreGState()

    // A dark recessed socket boosts contrast against the vivid inset tile.
    // A squared socket cuts across the R's bowl and diagonal so the insert
    // has an intentional home, instead of appearing to float on top.
    let squareRect = CGRect(x: 466, y: 401, width: 237, height: 237)
    let cx = squareRect.midX
    let cy = squareRect.midY
    var rotation = CGAffineTransform(translationX: cx, y: cy)
        .rotated(by: -.pi / 10)
        .translatedBy(x: -cx, y: -cy)

    let socketRect = squareRect.insetBy(dx: -20, dy: -20)
    let socket = CGPath(roundedRect: socketRect,
                        cornerWidth: 40, cornerHeight: 40,
                        transform: &rotation)
    context.addPath(socket)
    context.setFillColor(
        (appearance == .dark
            ? NSColor(calibratedRed: 0.075, green: 0.09, blue: 0.15, alpha: 1)
            : NSColor(calibratedRed: 0.18, green: 0.15, blue: 0.62, alpha: 1)).cgColor
    )
    context.fillPath()

    let square = CGPath(roundedRect: squareRect,
                        cornerWidth: 31, cornerHeight: 31,
                        transform: &rotation)
    context.saveGState()
    context.addPath(square)
    context.clip()
    context.drawLinearGradient(
        gradient(appearance == .light
            ? [
                NSColor(calibratedRed: 0.82, green: 0.36, blue: 1.00, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.16, green: 0.42, blue: 1.00, alpha: 1).cgColor
            ]
            : [
                NSColor(calibratedRed: 0.68, green: 0.28, blue: 0.99, alpha: 1).cgColor,
                NSColor(calibratedRed: 0.14, green: 0.44, blue: 1.00, alpha: 1).cgColor
            ]),
        start: CGPoint(x: 468, y: 690),
        end: CGPoint(x: 735, y: 386),
        options: []
    )
    context.restoreGState()

    context.addPath(square)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.56).cgColor)
    context.setLineWidth(9)
    context.strokePath()

    // Nested inner square: it aligns with the same rotation as its parent.
    let little = CGRect(x: cx - 43, y: cy - 43, width: 86, height: 86)
    let insetSquare = CGPath(roundedRect: little,
                             cornerWidth: 12, cornerHeight: 12,
                             transform: &rotation)
    context.addPath(insetSquare)
    context.setFillColor(
        appearance == .dark
            ? NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.53, alpha: 1).cgColor
            : NSColor(calibratedRed: 0.12, green: 0.24, blue: 0.79, alpha: 1).cgColor
    )
    context.fillPath()
    context.addPath(insetSquare)
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.63).cgColor)
    context.setLineWidth(6)
    context.strokePath()
}

guard CommandLine.arguments.count >= 2 else {
    fatalError("Expected project root directory")
}
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let appIcons = root.appendingPathComponent("MacExecutor/Assets.xcassets/AppIcon.appiconset",
                                            isDirectory: true)
let lightImages = root.appendingPathComponent("MacExecutor/Assets.xcassets/RebiliumLightIcon.imageset",
                                               isDirectory: true)
let darkImages = root.appendingPathComponent("MacExecutor/Assets.xcassets/RebiliumDarkIcon.imageset",
                                              isDirectory: true)
for folder in [appIcons, lightImages, darkImages] {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
}

func render(_ size: Int, style: IconAppearance) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Could not create icon bitmap: \(size)")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    graphics.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(graphics.cgContext, appearance: style)
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let bytes = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to serialize icon PNG")
    }
    return bytes
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    try render(size, style: .light)
        .write(to: appIcons.appendingPathComponent("rebilium_\(size).png"), options: .atomic)
}
// The two full-size images compile into the asset catalog for AppKit, so
// Rebilium can display a dark graphite Dock icon and matching header mark.
try render(1024, style: .light)
    .write(to: lightImages.appendingPathComponent("rebilium_light.png"), options: .atomic)
try render(1024, style: .dark)
    .write(to: darkImages.appendingPathComponent("rebilium_dark.png"), options: .atomic)
print("Generated Rebilium light and graphite-dark icons")
