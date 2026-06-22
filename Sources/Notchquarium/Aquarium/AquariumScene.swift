import AppKit
import SpriteKit

/// The living aquarium. A pure view of the latest `VitalsSnapshot`:
/// - water *level* = battery
/// - bubble *rate* = CPU
/// - water *clarity* (green murk) = memory pressure
/// - fish = top processes (added in the fish task)
final class AquariumScene: SKScene {
    private let waterNode = SKSpriteNode()
    private let memoryTint = SKSpriteNode()
    private var bubbleEmitter = SKEmitterNode()

    /// Tuning constants for the vitals→visuals mapping.
    private let maxBubbleRate: CGFloat = 60
    private let maxMurkAlpha: CGFloat = 0.45

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
        buildScene()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
        buildScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    private func buildScene() {
        backgroundColor = NSColor(calibratedRed: 0.02, green: 0.05, blue: 0.10, alpha: 1)

        // Aqua -> sky vertical gradient water body, anchored at the bottom.
        waterNode.texture = SpriteTextures.verticalGradient(
            size: CGSize(width: 64, height: 256),
            top: NSColor(calibratedRed: 0.55, green: 0.85, blue: 0.98, alpha: 1),
            bottom: NSColor(calibratedRed: 0.10, green: 0.45, blue: 0.70, alpha: 1)
        )
        waterNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        waterNode.zPosition = 0
        addChild(waterNode)

        // Green murk overlay; alpha rises with memory pressure.
        memoryTint.color = NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.20, alpha: 1)
        memoryTint.colorBlendFactor = 1
        memoryTint.texture = nil
        memoryTint.anchorPoint = CGPoint(x: 0.5, y: 0)
        memoryTint.alpha = 0
        memoryTint.zPosition = 6
        addChild(memoryTint)

        bubbleEmitter = BubbleEmitter.make(width: size.width)
        addChild(bubbleEmitter)

        layout()
    }

    /// Re-place nodes for the current scene size.
    private func layout() {
        waterNode.size = CGSize(width: size.width, height: waterNode.size.height == 0 ? size.height : waterNode.size.height)
        waterNode.position = CGPoint(x: size.width / 2, y: 0)
        memoryTint.size = CGSize(width: size.width, height: size.height)
        memoryTint.position = CGPoint(x: size.width / 2, y: 0)
        bubbleEmitter.position = CGPoint(x: size.width / 2, y: 0)
        bubbleEmitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
    }

    /// Apply a vitals snapshot to the scene (animated).
    func apply(_ snapshot: VitalsSnapshot) {
        let level = CGFloat(snapshot.batteryFraction ?? 1)
        let targetHeight = max(size.height * level, 8)
        waterNode.run(.resize(toHeight: targetHeight, duration: 0.6))

        bubbleEmitter.particleBirthRate = CGFloat(snapshot.cpuFraction) * maxBubbleRate

        let murk = CGFloat(snapshot.memoryUsedFraction) * maxMurkAlpha
        memoryTint.run(.fadeAlpha(to: murk, duration: 0.6))
    }
}
