import AppKit

/// A borderless, non-activating floating panel anchored to the notch that
/// resizes between the three `NotchState`s. Hover expands it to `.peek`,
/// clicking toggles `.expanded`, and leaving collapses back to `.ambient`.
final class NotchPanel: NSPanel {
    private let screenFrame: CGRect
    private let notchSize: CGSize
    private(set) var state: NotchState = .ambient
    private var collapseWork: DispatchWorkItem?

    /// Called whenever the state changes, for chrome that depends on it.
    var onStateChange: ((NotchState) -> Void)?

    init(screenFrame: CGRect, notchSize: CGSize, content: NSView) {
        self.screenFrame = screenFrame
        self.notchSize = notchSize
        let frame = NotchGeometry.tankFrame(screenFrame: screenFrame, notchSize: notchSize, state: .ambient)
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        content.frame = CGRect(origin: .zero, size: frame.size)
        content.autoresizingMask = [.width, .height]
        contentView = content

        let tracking = NSTrackingArea(
            rect: content.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        content.addTrackingArea(tracking)
    }

    override var canBecomeKey: Bool { false }

    func show() {
        setState(.ambient, animated: false)
        orderFrontRegardless()
    }

    func setState(_ newState: NotchState, animated: Bool) {
        state = newState
        onStateChange?(newState)
        let frame = NotchGeometry.tankFrame(screenFrame: screenFrame, notchSize: notchSize, state: newState)
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.28
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(frame, display: true)
            }
        } else {
            setFrame(frame, display: true)
        }
    }

    // MARK: - Hover / click

    override func mouseEntered(with event: NSEvent) {
        collapseWork?.cancel()
        if state == .ambient { setState(.peek, animated: true) }
    }

    override func mouseExited(with event: NSEvent) {
        scheduleCollapse()
    }

    override func mouseDown(with event: NSEvent) {
        collapseWork?.cancel()
        setState(state == .expanded ? .peek : .expanded, animated: true)
    }

    private func scheduleCollapse() {
        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.setState(.ambient, animated: true)
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
