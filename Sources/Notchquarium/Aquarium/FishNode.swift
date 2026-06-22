import AppKit
import SpriteKit

/// A single fish representing one process. Size, speed and colour are driven by
/// the process's CPU usage; the node carries the app identity for tooltips.
final class FishNode: SKNode {
    let pid: pid_t
    private(set) var sample: ProcessSample
    private let sprite = SKSpriteNode()
    private static let textureSize = CGSize(width: 76, height: 46)

    /// Text shown in the hover tooltip, e.g. "Chrome — 41% CPU".
    var appLabel: String { "\(sample.name) — \(Int(sample.cpuPercent.rounded()))% CPU" }

    init(sample: ProcessSample) {
        self.pid = sample.pid
        self.sample = sample
        super.init()
        sprite.zPosition = 10
        addChild(sprite)
        apply(sample, animated: false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Update appearance from a new sample of the same process.
    func bind(_ sample: ProcessSample) {
        self.sample = sample
        apply(sample, animated: true)
    }

    private func apply(_ sample: ProcessSample, animated: Bool) {
        let load = min(max(sample.cpuPercent / 100, 0), 1)
        let scale = 0.6 + load * 1.0                   // 0.6 ... 1.6
        let hue = 0.55 - 0.55 * load                   // teal (calm) -> red (busy)

        sprite.texture = SpriteTextures.glossyFish(size: FishNode.textureSize, hue: hue)
        sprite.size = FishNode.textureSize

        if animated {
            run(.scale(to: scale, duration: 0.5))
        } else {
            setScale(scale)
        }
    }

    /// Begin a gentle, endless wander within the given bounds.
    func startWandering(in size: CGSize) {
        position = CGPoint(
            x: .random(in: size.width * 0.15 ... size.width * 0.85),
            y: .random(in: size.height * 0.2 ... size.height * 0.7)
        )
        wanderStep(in: size)
    }

    private func wanderStep(in size: CGSize) {
        let target = CGPoint(
            x: .random(in: size.width * 0.1 ... size.width * 0.9),
            y: .random(in: size.height * 0.15 ... size.height * 0.75)
        )
        // Faster fish for busier processes.
        let load = min(max(sample.cpuPercent / 100, 0), 1)
        let speed = 26.0 + load * 70.0 // points/sec
        let distance = hypot(target.x - position.x, target.y - position.y)
        let duration = max(Double(distance) / speed, 0.9)

        // Face the direction of travel (texture points right).
        xScale = abs(xScale) * (target.x >= position.x ? 1 : -1)

        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        // A little vertical bob for life.
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 4, duration: duration / 2),
            .moveBy(x: 0, y: -4, duration: duration / 2),
        ])
        run(.group([move, bob])) { [weak self] in
            self?.wanderStep(in: size)
        }
    }
}
