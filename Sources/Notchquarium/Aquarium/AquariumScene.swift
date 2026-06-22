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

    private var fishNodes: [pid_t: FishNode] = [:]
    private var currentProcesses: [ProcessSample] = []

    private let tooltip = TooltipNode()

    // Decorative (Frutiger Aero) chrome.
    private let specular = SKSpriteNode()
    private let gravel = SKNode()
    private let plant = SKShapeNode()
    private let rays = SKNode()

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

        buildDecor()

        tooltip.zPosition = 100
        tooltip.isHidden = true
        addChild(tooltip)

        layout()
    }

    private func buildDecor() {
        // Light rays slanting down from the top-left.
        for i in 0..<3 {
            let ray = SKShapeNode(rectOf: CGSize(width: 26, height: 600))
            ray.fillColor = NSColor(calibratedWhite: 1, alpha: 0.06)
            ray.strokeColor = .clear
            ray.blendMode = .add
            ray.zPosition = 3
            ray.zRotation = .pi / 7
            ray.position = CGPoint(x: 60 + CGFloat(i) * 70, y: 120)
            ray.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.9, duration: 3 + Double(i)),
                .fadeAlpha(to: 0.4, duration: 3 + Double(i)),
            ])))
            rays.addChild(ray)
        }
        addChild(rays)

        // Top specular gloss (additive white fading down).
        specular.texture = SpriteTextures.verticalGradient(
            size: CGSize(width: 64, height: 64),
            top: NSColor(calibratedWhite: 1, alpha: 0.0),
            bottom: NSColor(calibratedWhite: 1, alpha: 0.35)
        )
        specular.anchorPoint = CGPoint(x: 0.5, y: 1)
        specular.blendMode = .add
        specular.zPosition = 8
        addChild(specular)

        // Gravel pebbles along the floor.
        let pebbleColors = [
            NSColor(calibratedRed: 0.85, green: 0.78, blue: 0.62, alpha: 1),
            NSColor(calibratedRed: 0.72, green: 0.62, blue: 0.48, alpha: 1),
            NSColor(calibratedRed: 0.62, green: 0.70, blue: 0.66, alpha: 1),
        ]
        for i in 0..<40 {
            let r = CGFloat.random(in: 4...8)
            let pebble = SKShapeNode(circleOfRadius: r)
            pebble.fillColor = pebbleColors[i % pebbleColors.count]
            pebble.strokeColor = .clear
            pebble.position = CGPoint(x: CGFloat(i) * 14, y: CGFloat.random(in: 2...10))
            gravel.addChild(pebble)
        }
        gravel.zPosition = 7
        addChild(gravel)

        // A swaying seaweed blade.
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 0, y: 0))
        blade.addQuadCurve(to: CGPoint(x: 6, y: 60), control: CGPoint(x: 24, y: 30))
        blade.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: -12, y: 30))
        plant.path = blade
        plant.fillColor = NSColor(calibratedRed: 0.18, green: 0.6, blue: 0.32, alpha: 0.9)
        plant.strokeColor = .clear
        plant.zPosition = 7
        plant.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.12, duration: 2.2),
            .rotate(toAngle: -0.12, duration: 2.2),
        ])))
        addChild(plant)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        // Deliver mouseMoved so we can show fish tooltips on hover.
        view.window?.acceptsMouseMovedEvents = true
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
    }

    // MARK: - Hover tooltip

    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        let hit = nodes(at: location).compactMap { node -> FishNode? in
            node as? FishNode ?? node.parent as? FishNode
        }.first

        if let fish = hit {
            tooltip.setText(fish.appLabel)
            tooltip.position = CGPoint(x: fish.position.x, y: fish.position.y + 22)
            tooltip.isHidden = false
        } else {
            tooltip.isHidden = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        tooltip.isHidden = true
    }

    // MARK: - Fish

    private func applyFish(_ processes: [ProcessSample]) {
        for op in FishDiff.ops(current: currentProcesses, next: processes) {
            switch op {
            case .add(let sample):
                let fish = FishNode(sample: sample)
                fishNodes[sample.pid] = fish
                addChild(fish)
                fish.startWandering(in: size)
                fish.alpha = 0
                fish.run(.fadeIn(withDuration: 0.5))
            case .remove(let pid):
                if let fish = fishNodes.removeValue(forKey: pid) {
                    fish.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
                }
            case .update(let sample):
                fishNodes[sample.pid]?.bind(sample)
            }
        }
        currentProcesses = processes
    }

    /// Re-place nodes for the current scene size.
    private func layout() {
        waterNode.size = CGSize(width: size.width, height: waterNode.size.height == 0 ? size.height : waterNode.size.height)
        waterNode.position = CGPoint(x: size.width / 2, y: 0)
        memoryTint.size = CGSize(width: size.width, height: size.height)
        memoryTint.position = CGPoint(x: size.width / 2, y: 0)
        bubbleEmitter.position = CGPoint(x: size.width / 2, y: 0)
        bubbleEmitter.particlePositionRange = CGVector(dx: size.width, dy: 0)

        specular.position = CGPoint(x: size.width / 2, y: size.height)
        specular.size = CGSize(width: size.width, height: size.height * 0.5)
        gravel.position = CGPoint(x: 0, y: 0)
        plant.position = CGPoint(x: size.width - 40, y: 6)
    }

    /// Apply a vitals snapshot to the scene (animated).
    func apply(_ snapshot: VitalsSnapshot) {
        let level = CGFloat(snapshot.batteryFraction ?? 1)
        let targetHeight = max(size.height * level, 8)
        waterNode.run(.resize(toHeight: targetHeight, duration: 0.6))

        bubbleEmitter.particleBirthRate = CGFloat(snapshot.cpuFraction) * maxBubbleRate

        let murk = CGFloat(snapshot.memoryUsedFraction) * maxMurkAlpha
        memoryTint.run(.fadeAlpha(to: murk, duration: 0.6))

        applyFish(snapshot.topProcesses)
    }
}
