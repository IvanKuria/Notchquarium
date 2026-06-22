import AppKit
import SpriteKit

/// Programmatic Frutiger Aero textures — glossy glass, gradients, bokeh and
/// tropical fish — all drawn with CoreGraphics so the package needs no bundled
/// assets and the gloss is real lighting, not flat fills.
enum SpriteTextures {
    private static let rgb = CGColorSpaceCreateDeviceRGB()

    private static func draw(_ size: CGSize, _ body: @escaping (CGContext, CGRect) -> Void) -> SKTexture {
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            body(ctx, rect)
            return true
        }
        return SKTexture(image: image)
    }

    // MARK: - Gradients

    /// Vertical gradient from `bottom` (y=0) to `top` (y=max).
    static func verticalGradient(size: CGSize, top: NSColor, bottom: NSColor) -> SKTexture {
        draw(size) { ctx, rect in
            guard let g = CGGradient(colorsSpace: rgb, colors: [bottom.cgColor, top.cgColor] as CFArray, locations: [0, 1]) else { return }
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
    }

    /// A soft diagonal multi-stop "aurora" gradient (light moving across glass).
    static func diagonalGradient(size: CGSize, colors: [NSColor], locations: [CGFloat]) -> SKTexture {
        draw(size) { ctx, rect in
            guard let g = CGGradient(colorsSpace: rgb, colors: colors.map { $0.cgColor } as CFArray, locations: locations) else { return }
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    // MARK: - Glass

    /// A translucent glass bubble: faint aqua body, brighter rim, and a small
    /// bright specular highlight offset toward the top-left.
    static func glossyBubble(diameter: CGFloat) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        return draw(size) { ctx, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2 - 1

            // Body: translucent center, brighter rim (refraction).
            let body = [
                NSColor(calibratedRed: 0.80, green: 0.97, blue: 1.0, alpha: 0.04).cgColor,
                NSColor(calibratedRed: 0.65, green: 0.92, blue: 1.0, alpha: 0.10).cgColor,
                NSColor(calibratedRed: 0.95, green: 1.0, blue: 1.0, alpha: 0.55).cgColor,
            ]
            if let g = CGGradient(colorsSpace: rgb, colors: body as CFArray, locations: [0, 0.72, 1]) {
                ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
            }

            // Specular highlight (the glassy "shine").
            let hi = CGPoint(x: rect.midX - radius * 0.34, y: rect.midY + radius * 0.36)
            let hiColors = [NSColor(calibratedWhite: 1, alpha: 0.95).cgColor, NSColor(calibratedWhite: 1, alpha: 0).cgColor]
            if let g = CGGradient(colorsSpace: rgb, colors: hiColors as CFArray, locations: [0, 1]) {
                ctx.drawRadialGradient(g, startCenter: hi, startRadius: 0, endCenter: hi, endRadius: radius * 0.5, options: [])
            }
        }
    }

    /// A soft out-of-focus light circle (bokeh).
    static func bokeh(diameter: CGFloat, color: NSColor) -> SKTexture {
        let size = CGSize(width: diameter, height: diameter)
        return draw(size) { ctx, rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width / 2
            let colors = [
                color.withAlphaComponent(0.0).cgColor,
                color.withAlphaComponent(0.22).cgColor,
                color.withAlphaComponent(0.32).cgColor,
                color.withAlphaComponent(0.0).cgColor,
            ]
            if let g = CGGradient(colorsSpace: rgb, colors: colors as CFArray, locations: [0, 0.62, 0.85, 1]) {
                ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
            }
        }
    }

    // MARK: - Fish

    /// A glossy tropical fish pointing right: gradient body (saturated back,
    /// pale belly), tail + dorsal fins, an eye, and a bright sheen streak.
    static func glossyFish(size: CGSize, hue: CGFloat) -> SKTexture {
        return draw(size) { ctx, rect in
            let w = rect.width, h = rect.height
            let back = NSColor(hue: hue, saturation: 0.85, brightness: 0.95, alpha: 1)
            let belly = NSColor(hue: hue, saturation: 0.30, brightness: 1.0, alpha: 1)

            // Tail fin.
            let tail = NSBezierPath()
            tail.move(to: CGPoint(x: w * 0.22, y: h * 0.5))
            tail.line(to: CGPoint(x: w * 0.02, y: h * 0.82))
            tail.line(to: CGPoint(x: w * 0.10, y: h * 0.5))
            tail.line(to: CGPoint(x: w * 0.02, y: h * 0.18))
            tail.close()
            back.setFill(); tail.fill()

            // Dorsal fin.
            let dorsal = NSBezierPath()
            dorsal.move(to: CGPoint(x: w * 0.40, y: h * 0.72))
            dorsal.curve(to: CGPoint(x: w * 0.70, y: h * 0.74), controlPoint1: CGPoint(x: w * 0.5, y: h * 0.96), controlPoint2: CGPoint(x: w * 0.62, y: h * 0.95))
            dorsal.close()
            back.withAlphaComponent(0.9).setFill(); dorsal.fill()

            // Body (vertical gradient, saturated top → pale belly).
            let bodyRect = CGRect(x: w * 0.16, y: h * 0.24, width: w * 0.74, height: h * 0.52)
            let bodyPath = NSBezierPath(ovalIn: bodyRect)
            ctx.saveGState()
            bodyPath.addClip()
            if let g = CGGradient(colorsSpace: rgb, colors: [belly.cgColor, back.cgColor] as CFArray, locations: [0, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: bodyRect.midX, y: bodyRect.minY), end: CGPoint(x: bodyRect.midX, y: bodyRect.maxY), options: [])
            }
            ctx.restoreGState()

            // Sheen streak (gloss) on the upper body.
            let sheen = NSBezierPath(ovalIn: CGRect(x: w * 0.30, y: h * 0.52, width: w * 0.42, height: h * 0.16))
            NSColor(calibratedWhite: 1, alpha: 0.45).setFill(); sheen.fill()

            // Eye.
            let eyeC = CGPoint(x: w * 0.78, y: h * 0.56)
            NSColor.white.setFill(); NSBezierPath(ovalIn: CGRect(x: eyeC.x - 3.5, y: eyeC.y - 3.5, width: 7, height: 7)).fill()
            NSColor.black.setFill(); NSBezierPath(ovalIn: CGRect(x: eyeC.x - 1.8, y: eyeC.y - 1.8, width: 3.6, height: 3.6)).fill()
            NSColor.white.setFill(); NSBezierPath(ovalIn: CGRect(x: eyeC.x - 0.5, y: eyeC.y + 0.4, width: 1.6, height: 1.6)).fill()
        }
    }
}
