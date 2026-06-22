import AppKit
import SpriteKit

/// Programmatic textures so the package needs no bundled image/.sks assets.
enum SpriteTextures {
    /// A soft filled circle, used for bubbles and fish highlights.
    static func circle(diameter: CGFloat, color: NSColor) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        let image = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        return SKTexture(image: image)
    }

    /// A vertical gradient from `bottom` (y=0) to `top` (y=max).
    static func verticalGradient(size: CGSize, top: NSColor, bottom: NSColor) -> SKTexture {
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let colors = [bottom.cgColor, top.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else {
                return false
            }
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: []
            )
            return true
        }
        return SKTexture(image: image)
    }
}
