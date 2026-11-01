import Cocoa

/// The menu bar icon: an espresso cup on a saucer, drawn in code so it stays sharp at any resolution.
/// It uses one color only: as a template image, macOS tints it to suit the menu bar.
enum MenuBarIcon {
    private static let size = NSSize(width: 18, height: 18)
    private static let lineWidth: CGFloat = 1.5

    /// Off: outline only. Active: filled cup with two curls of steam.
    static func image(active: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            draw(active: active)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Tazza"
        return image
    }

    // All coordinates are in points on the 18x18 canvas, with the origin at the bottom left.
    // Horizontal edges fall on half points, so they land on whole pixels on a Retina display and stay crisp.
    private static func draw(active: Bool) {
        let cup = cupPath()
        if active { cup.fill() }
        stroke(cup) // also when filled, so the cup has the same outer shape in both states
        stroke(handlePath())
        NSBezierPath(roundedRect: NSRect(x: 2.25, y: 2, width: 11.5, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()
        if active {
            stroke(steamPath(x: 6.2))
            stroke(steamPath(x: 9.8))
        }
    }

    private static func stroke(_ path: NSBezierPath) {
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }

    /// Short and tapered towards the base, unlike a straight-sided mug.
    private static func cupPath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 3.9, y: 10.25))
        path.line(to: NSPoint(x: 12.1, y: 10.25))
        path.curve(to: NSPoint(x: 9.8, y: 4.75),
                   controlPoint1: NSPoint(x: 12.1, y: 7.4), controlPoint2: NSPoint(x: 11.3, y: 5.4))
        path.line(to: NSPoint(x: 6.2, y: 4.75))
        path.curve(to: NSPoint(x: 3.9, y: 10.25),
                   controlPoint1: NSPoint(x: 4.7, y: 5.4), controlPoint2: NSPoint(x: 3.9, y: 7.4))
        path.close()
        return path
    }

    private static func handlePath() -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 12, y: 9.4))
        path.curve(to: NSPoint(x: 11.1, y: 6),
                   controlPoint1: NSPoint(x: 16.8, y: 10.4), controlPoint2: NSPoint(x: 16.4, y: 5.4))
        return path
    }

    /// A small S curve rising from the cup.
    private static func steamPath(x: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: 12))
        path.curve(to: NSPoint(x: x + 0.3, y: 16),
                   controlPoint1: NSPoint(x: x + 1.8, y: 13.3), controlPoint2: NSPoint(x: x - 1.5, y: 14.6))
        return path
    }
}
