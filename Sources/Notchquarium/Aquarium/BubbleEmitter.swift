import AppKit
import SpriteKit

/// Builds the rising-bubble emitter. Birth rate is set later from CPU load.
enum BubbleEmitter {
    static func make(width: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = SpriteTextures.circle(diameter: 10, color: .white)
        emitter.particleBirthRate = 0 // driven by CPU in AquariumScene.apply
        emitter.particleLifetime = 4
        emitter.particleLifetimeRange = 1.5

        // Spawn across the bottom, drift upward with a little wobble.
        emitter.particlePositionRange = CGVector(dx: width, dy: 0)
        emitter.particleSpeed = 35
        emitter.particleSpeedRange = 15
        emitter.emissionAngle = .pi / 2 // straight up
        emitter.emissionAngleRange = .pi / 8
        emitter.xAcceleration = 0
        emitter.yAcceleration = 8

        emitter.particleScale = 0.18
        emitter.particleScaleRange = 0.12
        emitter.particleAlpha = 0.5
        emitter.particleAlphaRange = 0.2
        emitter.particleAlphaSpeed = -0.12
        emitter.particleBlendMode = .add
        emitter.zPosition = 5
        return emitter
    }
}
