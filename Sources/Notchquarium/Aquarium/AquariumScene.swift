import AppKit
import SpriteKit

/// The living aquarium. A pure view of the latest `VitalsSnapshot`:
/// - water *level* = battery
/// - bubble *rate* = CPU
/// - water *clarity* (green murk) = memory pressure
/// - fish = top processes
///
/// Visuals follow the Frutiger Aero recipe: a soft aurora sky, a glossy
/// aqua→lime water body with a bright glassy surface line, drifting bokeh,
/// light shafts, glass bubbles and gradient tropical fish.
final class AquariumScene: SKScene {
    private let sky = SKSpriteNode()
    private let waterNode = SKSpriteNode()
    private let waterSheen = SKSpriteNode()
    private let waterline = SKSpriteNode()
    private let memoryTint = SKSpriteNode()
    private var bubbleEmitter = SKEmitterNode()

    private var fishNodes: [pid_t: FishNode] = [:]
    private var currentProcesses: [ProcessSample] = []

    private let tooltip = TooltipNode()

    // Decorative chrome.
    private let bokehLayer = SKNode()
    private let gravel = SKNode()
    private let plant = SKNode()
    private let rays = SKNode()
    private let glassSheen = SKSpriteNode()

    private var waterFraction: CGFloat = 1

    /// Tuning constants for the vitals→visuals mapping.
    private let maxBubbleRate: CGFloat = 70
    private let maxMurkAlpha: CGFloat = 0.40

    override init(size: CGSize) {
        super.init(size: size)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0, y: 0)
        buildScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    // MARK: - Build

    private func buildScene() {
        backgroundColor = .clear

        // Aurora sky behind the water (visible above the waterline).
        sky.texture = SpriteTextures.diagonalGradient(
            size: CGSize(width: 256, height: 256),
            colors: [
                NSColor(calibratedRed: 0.46, green: 0.78, blue: 0.96, alpha: 1), // sky blue
                NSColor(calibratedRed: 0.74, green: 0.93, blue: 1.00, alpha: 1), // pale cyan
                NSColor(calibratedRed: 0.93, green: 0.99, blue: 0.96, alpha: 1), // near-white horizon
            ],
            locations: [0, 0.6, 1]
        )
        sky.anchorPoint = CGPoint(x: 0.5, y: 0)
        sky.zPosition = -10
        addChild(sky)

        // Glossy aqua -> lime/teal water body, anchored at the bottom.
        waterNode.texture = SpriteTextures.verticalGradient(
            size: CGSize(width: 64, height: 256),
            top: NSColor(calibratedRed: 0.56, green: 0.90, blue: 0.92, alpha: 1),   // bright aqua surface
            bottom: NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.45, alpha: 1) // deep teal-green
        )
        waterNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        waterNode.zPosition = 0
        addChild(waterNode)

        // Soft top sheen inside the water (light entering the surface).
        waterSheen.texture = SpriteTextures.verticalGradient(
            size: CGSize(width: 64, height: 64),
            top: NSColor(calibratedWhite: 1, alpha: 0.30),
            bottom: NSColor(calibratedWhite: 1, alpha: 0.0)
        )
        waterSheen.anchorPoint = CGPoint(x: 0.5, y: 1)
        waterSheen.blendMode = .add
        waterSheen.zPosition = 1
        addChild(waterSheen)

        // Bright glassy waterline (the meniscus highlight).
        waterline.texture = SpriteTextures.verticalGradient(
            size: CGSize(width: 64, height: 8),
            top: NSColor(calibratedRed: 0.85, green: 1.0, blue: 1.0, alpha: 0.0),
            bottom: NSColor(calibratedRed: 0.90, green: 1.0, blue: 1.0, alpha: 0.85)
        )
        waterline.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        waterline.blendMode = .add
        waterline.zPosition = 4
        addChild(waterline)

        // Green murk overlay; alpha rises with memory pressure.
        memoryTint.color = NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.22, alpha: 1)
        memoryTint.colorBlendFactor = 1
        memoryTint.anchorPoint = CGPoint(x: 0.5, y: 0)
        memoryTint.alpha = 0
        memoryTint.zPosition = 2
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
        // Light shafts slanting down from the top.
        for i in 0..<4 {
            let shaft = SKSpriteNode(texture: SpriteTextures.verticalGradient(
                size: CGSize(width: 40, height: 400),
                top: NSColor(calibratedWhite: 1, alpha: 0.10),
                bottom: NSColor(calibratedWhite: 1, alpha: 0.0)
            ))
            shaft.anchorPoint = CGPoint(x: 0.5, y: 1)
            shaft.blendMode = .add
            shaft.zPosition = 3
            shaft.zRotation = .pi / 9
            shaft.position = CGPoint(x: 50 + CGFloat(i) * 90, y: 260)
            shaft.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.9, duration: 3 + Double(i) * 0.7),
                .fadeAlpha(to: 0.35, duration: 3 + Double(i) * 0.7),
            ])))
            rays.addChild(shaft)
        }
        addChild(rays)

        // Drifting bokeh (soft out-of-focus light circles).
        let bokehColors = [
            NSColor(calibratedRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.7, green: 0.95, blue: 1.0, alpha: 1),
            NSColor(calibratedRed: 0.75, green: 1.0, blue: 0.7, alpha: 1), // lime
        ]
        for i in 0..<7 {
            let d = CGFloat.random(in: 26...70)
            let dot = SKSpriteNode(texture: SpriteTextures.bokeh(diameter: d, color: bokehColors[i % bokehColors.count]))
            dot.size = CGSize(width: d, height: d)
            dot.blendMode = .add
            dot.zPosition = 9
            dot.alpha = CGFloat.random(in: 0.3...0.7)
            bokehLayer.addChild(dot)
        }
        bokehLayer.zPosition = 9
        addChild(bokehLayer)

        // Gravel pebbles along the floor (bright, sunlit).
        let pebbleColors = [
            NSColor(calibratedRed: 0.95, green: 0.90, blue: 0.74, alpha: 1),
            NSColor(calibratedRed: 0.82, green: 0.72, blue: 0.56, alpha: 1),
            NSColor(calibratedRed: 0.72, green: 0.84, blue: 0.72, alpha: 1),
            NSColor(calibratedRed: 0.88, green: 0.80, blue: 0.86, alpha: 1),
        ]
        for i in 0..<60 {
            let r = CGFloat.random(in: 4...9)
            let pebble = SKShapeNode(circleOfRadius: r)
            pebble.fillColor = pebbleColors[i % pebbleColors.count]
            pebble.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.25)
            pebble.lineWidth = 0.5
            pebble.position = CGPoint(x: CGFloat(i) * 11, y: CGFloat.random(in: 2...12))
            gravel.addChild(pebble)
        }
        gravel.zPosition = 7
        addChild(gravel)

        // Two swaying seaweed blades.
        for (idx, dx) in [CGFloat(-14), 10].enumerated() {
            let blade = SKShapeNode()
            let path = CGMutablePath()
            let height: CGFloat = idx == 0 ? 70 : 54
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(to: CGPoint(x: 6, y: height), control: CGPoint(x: 26, y: height / 2))
            path.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: -14, y: height / 2))
            blade.path = path
            blade.fillColor = NSColor(calibratedRed: 0.30, green: 0.74, blue: 0.36, alpha: 0.92)
            blade.strokeColor = .clear
            blade.position = CGPoint(x: dx, y: 0)
            blade.run(.repeatForever(.sequence([
                .rotate(toAngle: 0.14, duration: 2.2 + Double(idx) * 0.4),
                .rotate(toAngle: -0.14, duration: 2.2 + Double(idx) * 0.4),
            ])))
            plant.addChild(blade)
        }
        plant.zPosition = 7
        addChild(plant)

        // Glass panel sheen across the very top (the "screen" reflection).
        glassSheen.texture = SpriteTextures.verticalGradient(
            size: CGSize(width: 64, height: 64),
            top: NSColor(calibratedWhite: 1, alpha: 0.28),
            bottom: NSColor(calibratedWhite: 1, alpha: 0.0)
        )
        glassSheen.anchorPoint = CGPoint(x: 0.5, y: 1)
        glassSheen.blendMode = .add
        glassSheen.zPosition = 50
        addChild(glassSheen)
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.window?.acceptsMouseMovedEvents = true
        let area = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
        startBokehDrift()
    }

    private func startBokehDrift() {
        for dot in bokehLayer.children {
            animateBokeh(dot)
        }
    }

    private func animateBokeh(_ dot: SKNode) {
        dot.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
        let drift = SKAction.moveBy(x: .random(in: -40...40), y: .random(in: 40...120), duration: .random(in: 8...16))
        drift.timingMode = .easeInEaseOut
        dot.run(drift) { [weak self, weak dot] in
            guard let self, let dot else { return }
            self.animateBokeh(dot)
        }
    }

    // MARK: - Hover tooltip

    override func mouseMoved(with event: NSEvent) {
        let location = event.location(in: self)
        let hit = nodes(at: location).compactMap { node -> FishNode? in
            node as? FishNode ?? node.parent as? FishNode
        }.first

        if let fish = hit {
            tooltip.setText(fish.appLabel)
            tooltip.position = CGPoint(x: fish.position.x, y: fish.position.y + 26)
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
                fish.zPosition = 10
                addChild(fish)
                fish.startWandering(in: CGSize(width: size.width, height: size.height * waterFraction))
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

    // MARK: - Layout

    private func layout() {
        sky.size = CGSize(width: size.width, height: size.height)
        sky.position = CGPoint(x: size.width / 2, y: 0)

        let waterHeight = max(size.height * waterFraction, 8)

        waterNode.size = CGSize(width: size.width, height: waterHeight)
        waterNode.position = CGPoint(x: size.width / 2, y: 0)

        waterSheen.size = CGSize(width: size.width, height: min(60, waterHeight))
        waterSheen.position = CGPoint(x: size.width / 2, y: waterHeight)

        waterline.size = CGSize(width: size.width, height: 8)
        waterline.position = CGPoint(x: size.width / 2, y: waterHeight)

        memoryTint.size = CGSize(width: size.width, height: waterHeight)
        memoryTint.position = CGPoint(x: size.width / 2, y: 0)

        bubbleEmitter.position = CGPoint(x: size.width / 2, y: 0)
        bubbleEmitter.particlePositionRange = CGVector(dx: size.width, dy: 0)

        gravel.position = .zero
        plant.position = CGPoint(x: size.width - 42, y: 6)

        glassSheen.size = CGSize(width: size.width, height: size.height * 0.4)
        glassSheen.position = CGPoint(x: size.width / 2, y: size.height)
    }

    // MARK: - Apply snapshot

    func apply(_ snapshot: VitalsSnapshot) {
        waterFraction = CGFloat(snapshot.batteryFraction ?? 1)
        let waterHeight = max(size.height * waterFraction, 8)

        waterNode.run(.resize(toHeight: waterHeight, duration: 0.6))
        memoryTint.run(.resize(toHeight: waterHeight, duration: 0.6))
        waterline.run(.moveTo(y: waterHeight, duration: 0.6))
        waterSheen.run(.moveTo(y: waterHeight, duration: 0.6))

        bubbleEmitter.particleBirthRate = CGFloat(snapshot.cpuFraction) * maxBubbleRate

        let murk = CGFloat(snapshot.memoryUsedFraction) * maxMurkAlpha
        memoryTint.run(.fadeAlpha(to: murk, duration: 0.6))

        applyFish(snapshot.topProcesses)
    }
}
