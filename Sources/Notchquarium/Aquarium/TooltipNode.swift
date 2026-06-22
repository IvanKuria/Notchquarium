import AppKit
import SpriteKit

/// A small glossy label that floats above a hovered fish.
final class TooltipNode: SKNode {
    private let label = SKLabelNode(fontNamed: "Helvetica-Bold")
    private let background = SKShapeNode()

    override init() {
        super.init()
        background.fillColor = NSColor(calibratedWhite: 0, alpha: 0.55)
        background.strokeColor = NSColor(calibratedWhite: 1, alpha: 0.25)
        background.lineWidth = 1
        addChild(background)

        label.fontSize = 12
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setText(_ text: String) {
        label.text = text
        let width = label.frame.width + 18
        let height: CGFloat = 22
        background.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
            cornerWidth: 8, cornerHeight: 8, transform: nil
        )
    }
}
