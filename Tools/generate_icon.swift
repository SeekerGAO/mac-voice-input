import AppKit

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let appBundleURL = rootURL.appending(path: "AppBundle", directoryHint: .isDirectory)
let iconsetURL = appBundleURL.appending(path: "AppIcon.iconset", directoryHint: .isDirectory)
let icnsURL = appBundleURL.appending(path: "AppIcon.icns")

let iconSizes: [(name: String, size: CGFloat)] = [
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

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for entry in iconSizes {
    let image = NSImage(size: NSSize(width: entry.size, height: entry.size))
    image.lockFocus()
    drawIcon(in: NSRect(x: 0, y: 0, width: entry.size, height: entry.size))
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to generate PNG for \(entry.name)")
    }
    try pngData.write(to: iconsetURL.appending(path: entry.name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}

try? fileManager.removeItem(at: iconsetURL)

func drawIcon(in rect: NSRect) {
    let radius = rect.width * 0.23
    let backgroundRect = rect.insetBy(dx: rect.width * 0.04, dy: rect.height * 0.04)
    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.07, green: 0.10, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.10, green: 0.24, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.64, alpha: 1)
    ])!
    gradient.draw(in: backgroundPath, angle: 315)

    NSGraphicsContext.current?.saveGraphicsState()
    backgroundPath.addClip()

    let glowRect = NSRect(
        x: rect.minX + rect.width * 0.10,
        y: rect.minY + rect.height * 0.50,
        width: rect.width * 0.80,
        height: rect.height * 0.42
    )
    let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.22),
        NSColor.white.withAlphaComponent(0.0)
    ])!
    glow.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: .zero)
    NSGraphicsContext.current?.restoreGraphicsState()

    let capsuleWidth = rect.width * 0.64
    let capsuleHeight = rect.height * 0.26
    let capsuleRect = NSRect(
        x: rect.midX - capsuleWidth / 2,
        y: rect.midY - capsuleHeight / 2 - rect.height * 0.02,
        width: capsuleWidth,
        height: capsuleHeight
    )
    let capsule = NSBezierPath(roundedRect: capsuleRect, xRadius: capsuleHeight / 2, yRadius: capsuleHeight / 2)
    NSColor.white.withAlphaComponent(0.18).setFill()
    capsule.fill()
    NSColor.white.withAlphaComponent(0.22).setStroke()
    capsule.lineWidth = max(2, rect.width * 0.012)
    capsule.stroke()

    let bars: [CGFloat] = [0.46, 0.72, 1.0, 0.76, 0.5]
    let barWidth = capsuleRect.width * 0.055
    let barSpacing = capsuleRect.width * 0.053
    let barsOriginX = capsuleRect.minX + capsuleRect.width * 0.15
    let centerY = capsuleRect.midY

    for (index, scale) in bars.enumerated() {
        let height = capsuleRect.height * (0.28 + 0.52 * scale)
        let x = barsOriginX + CGFloat(index) * (barWidth + barSpacing)
        let barRect = NSRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
        let barPath = NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2)
        NSColor.white.withAlphaComponent(index == 2 ? 0.95 : 0.82).setFill()
        barPath.fill()
    }

    let micRingRect = NSRect(
        x: capsuleRect.maxX - capsuleRect.height * 0.92,
        y: capsuleRect.midY - capsuleRect.height * 0.35,
        width: capsuleRect.height * 0.70,
        height: capsuleRect.height * 0.70
    )
    let ring = NSBezierPath(ovalIn: micRingRect)
    NSColor.white.withAlphaComponent(0.90).setStroke()
    ring.lineWidth = max(2, rect.width * 0.012)
    ring.stroke()

    let stemRect = NSRect(
        x: micRingRect.midX - micRingRect.width * 0.10,
        y: micRingRect.minY - micRingRect.height * 0.28,
        width: micRingRect.width * 0.20,
        height: micRingRect.height * 0.34
    )
    NSBezierPath(roundedRect: stemRect, xRadius: stemRect.width / 2, yRadius: stemRect.width / 2).fill()

    let baseRect = NSRect(
        x: micRingRect.midX - micRingRect.width * 0.22,
        y: stemRect.minY - micRingRect.height * 0.16,
        width: micRingRect.width * 0.44,
        height: micRingRect.height * 0.08
    )
    NSBezierPath(roundedRect: baseRect, xRadius: baseRect.height / 2, yRadius: baseRect.height / 2).fill()

    let borderPath = NSBezierPath(roundedRect: backgroundRect, xRadius: radius, yRadius: radius)
    NSColor.white.withAlphaComponent(0.12).setStroke()
    borderPath.lineWidth = max(2, rect.width * 0.01)
    borderPath.stroke()
}
