// Draws the DMG window background. Run: swift scripts/dmg/background.swift <scale> <out.png>
import AppKit

let scale = CGFloat(Double(CommandLine.arguments[1]) ?? 1)
let output = CommandLine.arguments[2]
let size = NSSize(width: 640, height: 400)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
rep.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let bounds = NSRect(origin: .zero, size: size)

// light cream, Finder draws the icon labels in black on a background picture
NSGradient(colors: [color(0xFFF9F1), color(0xF7EADB), color(0xEFDCC4)], atLocations: [0, 0.6, 1], colorSpace: .sRGB)!
    .draw(in: bounds, angle: -90)

// soft spotlights behind the two icons (icons sit at x 170 and 470, y 200 from the top)
for x in [170.0, 470.0] {
    let center = NSPoint(x: x, y: size.height - 200)
    NSGradient(colors: [color(0xFFFFFF, 0.85), color(0xFFFFFF, 0)])!
        .draw(fromCenter: center, radius: 0, toCenter: center, radius: 110, options: [])
}

// dashed curved arrow from the app to Applications
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 258, y: size.height - 196))
arrow.curve(to: NSPoint(x: 374, y: size.height - 194), controlPoint1: NSPoint(x: 290, y: size.height - 150), controlPoint2: NSPoint(x: 344, y: size.height - 150))
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.setLineDash([2, 10], count: 2, phase: 0)
color(0xC07A40).setStroke()
arrow.stroke()

// arrowhead follows the curve's direction at its end
let tip = NSPoint(x: 380, y: size.height - 200)
let angle = atan2(tip.y - (size.height - 150), tip.x - 344)
let head = NSBezierPath()
for side in [-1.0, 1.0] {
    let wing = angle + .pi - side * .pi / 6
    head.move(to: NSPoint(x: tip.x + cos(wing) * 16, y: tip.y + sin(wing) * 16))
    head.line(to: tip)
}
head.lineWidth = 4
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.stroke()

func draw(_ text: String, size fontSize: CGFloat, weight: NSFont.Weight, color textColor: NSColor, centerY: CGFloat) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: textColor,
        .paragraphStyle: style,
        .kern: 0.2,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let height = string.size().height
    string.draw(in: NSRect(x: 0, y: size.height - centerY - height / 2, width: size.width, height: height))
}

draw("Macaffeine", size: 26, weight: .semibold, color: color(0x4A2A18), centerY: 50)
draw("Drag the cup into Applications", size: 14, weight: .regular, color: color(0x8A5A38), centerY: 340)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
