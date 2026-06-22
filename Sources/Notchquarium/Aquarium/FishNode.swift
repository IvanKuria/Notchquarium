import AppKit
import SpriteKit

/// A single fish representing one process. Size, speed and colour are driven by
/// the process's CPU usage; the node carries the app identity for tooltips.
final class FishNode: SKNode {
    let pid: pid_t
    private(set) var sample: ProcessSample
    private let body = SKShapeNode()

    /// Text shown in the hover tooltip, e.g. "Chrome — 41% CPU".
    var appLabel: String { "\(sample.name) — \(Int(sample.cpuPercent.rounded()))% CPU" }

    init(sample: ProcessSample) {
        self.pid = sample.pid
        self.sample = sample
        super.init()
        body.path = FishNode.makeBodyPath()
        body.lineWidth = 0
        body.zPosition = 10
        addChild(body)
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
        let scale = 0.6 + load * 1.0                  // 0.6 ... 1.6
        let hue = 0.55 * (1 - load)                   // teal (calm) -> red (busy)
        let color = NSColor(hue: hue, saturation: 0.7, brightness: 0.95, alpha: 1)

        if animated {
            run(.scale(to: scale, duration: 0.5))
        } else {
            setScale(scale)
        }
        body.fillColor = color
    }

    /// Begin a gentle, endless wander within the given bounds.
    func startWandering(in size: CGSize) {
        position = CGPoint(
            x: .random(in: size.width * 0.15 ... size.width * 0.85),
            y: .random(in: size.height * 0.2 ... size.height * 0.8)
        )
        wanderStep(in: size)
    }

    private func wanderStep(in size: CGSize) {
        let target = CGPoint(
            x: .random(in: size.width * 0.1 ... size.width * 0.9),
            y: .random(in: size.height * 0.15 ... size.height * 0.85)
        )
        // Faster fish for busier processes.
        let load = min(max(sample.cpuPercent / 100, 0), 1)
        let speed = 30.0 + load * 70.0 // points/sec
        let distance = hypot(target.x - position.x, target.y - position.y)
        let duration = max(Double(distance) / speed, 0.8)

        // Face the direction of travel.
        xScale = abs(xScale) * (target.x >= position.x ? 1 : -1)

        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeInEaseOut
        run(move) { [weak self] in
            guard let self else { return }
            self.wanderStep(in: size)
        }
    }

    /// A simple fish silhouette: rounded body + triangular tail, pointing right.
    private static func makeBodyPath() -> CGPath {
        let path = CGMutablePath()
        // Body
        path.addEllipse(in: CGRect(x: -14, y: -7, width: 28, height: 14))
        // Tail
        path.move(to: CGPoint(x: -12, y: 0))
        path.addLine(to: CGPoint(x: -22, y: 8))
        path.addLine(to: CGPoint(x: -22, y: -8))
        path.closeSubpath()
        return path
    }
}
