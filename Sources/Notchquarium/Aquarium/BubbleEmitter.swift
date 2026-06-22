import AppKit
import SpriteKit

/// Builds the rising-bubble emitter using translucent glass bubbles. Birth rate
/// is set later from CPU load.
enum BubbleEmitter {
    static func make(width: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SpriteTextures.glossyBubble(diameter: 48)
        emitter.particleBirthRate = 0 // driven by CPU in AquariumScene.apply
        emitter.particleLifetime = 5
        emitter.particleLifetimeRange = 2

        // Spawn across the bottom, drift upward with a little wobble.
        emitter.particlePositionRange = CGVector(dx: width, dy: 0)
        emitter.particleSpeed = 32
        emitter.particleSpeedRange = 16
        emitter.emissionAngle = .pi / 2 // straight up
        emitter.emissionAngleRange = .pi / 10
        emitter.yAcceleration = 6

        // Varied glass bubble sizes; gently grow as they rise.
        emitter.particleScale = 0.22
        emitter.particleScaleRange = 0.20
        emitter.particleScaleSpeed = 0.04

        emitter.particleAlpha = 0.85
        emitter.particleAlphaRange = 0.15
        emitter.particleAlphaSpeed = -0.10
        emitter.particleBlendMode = .alpha // glass, not glow
        emitter.particleRotationRange = .pi
        emitter.zPosition = 5
        return emitter
    }
}
