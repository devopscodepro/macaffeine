import AppKit

// same cup as the app icon, drawn as a template so the menu bar tints it
enum MenuBarIcon {
    static func image(isActive: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            draw(isActive: isActive)
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func draw(isActive: Bool) {
        NSColor.black.set()
        let lineWidth: CGFloat = 1.4

        let saucer = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.3, width: 14, height: 1.6), xRadius: 0.8, yRadius: 0.8)
        saucer.fill()

        let cup = NSBezierPath()
        cup.move(to: NSPoint(x: 3.2, y: 11))
        cup.line(to: NSPoint(x: 13.2, y: 11))
        cup.curve(to: NSPoint(x: 10.2, y: 3.8), controlPoint1: NSPoint(x: 13.2, y: 7), controlPoint2: NSPoint(x: 12.4, y: 4.4))
        cup.line(to: NSPoint(x: 6.2, y: 3.8))
        cup.curve(to: NSPoint(x: 3.2, y: 11), controlPoint1: NSPoint(x: 4, y: 4.4), controlPoint2: NSPoint(x: 3.2, y: 7))
        cup.close()

        let handle = NSBezierPath(ovalIn: NSRect(x: 12, y: 6, width: 4.4, height: 4.4))
        handle.lineWidth = lineWidth
        handle.stroke()

        if isActive {
            cup.fill()
            for (x, height) in [(5.6, 4.2), (8.2, 5.2), (10.8, 4.2)] {
                steam(x: x, height: height, lineWidth: lineWidth - 0.2).stroke()
            }
        } else {
            cup.lineWidth = lineWidth
            cup.lineJoinStyle = .round
            cup.stroke()
        }
    }

    private static func steam(x: CGFloat, height: CGFloat, lineWidth: CGFloat) -> NSBezierPath {
        let bottom: CGFloat = 12.4
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: bottom))
        path.curve(
            to: NSPoint(x: x, y: bottom + height),
            controlPoint1: NSPoint(x: x + 1.4, y: bottom + height * 0.33),
            controlPoint2: NSPoint(x: x - 1.4, y: bottom + height * 0.66)
        )
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        return path
    }
}
