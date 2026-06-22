import AppKit
import Combine
import SpriteKit
import SwiftUI

/// Owns the app lifecycle: wires the vitals poller, the SpriteKit aquarium, the
/// notch panel state machine, and the menu-bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let vitals = SystemVitals()
    private let scene = AquariumScene(size: CGSize(width: 460, height: 240))
    private var panel: NotchPanel?
    private var statHost: NSHostingView<StatBar>?
    private var menuBar: MenuBarController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        vitals.start()
        debugLogIfRequested()

        guard let screen = NSScreen.main else { return }
        let notchSize = notchSize(for: screen)

        // Content = SKView (fills) + StatBar overlay along the bottom.
        let expanded = NotchGeometry.tankFrame(screenFrame: screen.frame, notchSize: notchSize, state: .expanded)
        let container = NSView(frame: CGRect(origin: .zero, size: expanded.size))
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.masksToBounds = true
        container.layer?.cornerCurve = .continuous

        let skView = SKView(frame: container.bounds)
        skView.autoresizingMask = [.width, .height]
        skView.allowsTransparency = true
        skView.presentScene(scene)
        container.addSubview(skView)

        let statBar = StatBar(vitals: vitals)
        let host = NSHostingView(rootView: statBar)
        host.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host)
        NSLayoutConstraint.activate([
            host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        host.isHidden = true
        self.statHost = host

        // Panel + state machine.
        let panel = NotchPanel(screenFrame: screen.frame, notchSize: notchSize, content: container)
        panel.onStateChange = { [weak host] state in
            host?.isHidden = (state != .expanded)
        }
        panel.show()
        if ProcessInfo.processInfo.environment["NQ_START_EXPANDED"] == "1" {
            panel.setState(.expanded, animated: false)
        }
        self.panel = panel

        // Menu bar.
        menuBar = MenuBarController(onToggle: { [weak panel] in
            guard let panel else { return }
            panel.setState(panel.state == .expanded ? .ambient : .expanded, animated: true)
        })

        // Feed vitals into the scene.
        vitals.$snapshot
            .sink { [weak scene] snapshot in
                scene?.apply(snapshot)
            }
            .store(in: &cancellables)
    }

    /// Best-effort notch size: use the screen's safe-area / auxiliary top inset
    /// when present, else a sensible default.
    private func notchSize(for screen: NSScreen) -> CGSize {
        let topInset = screen.safeAreaInsets.top
        let height = topInset > 0 ? topInset : 32
        // auxiliaryTopLeftArea width gives a hint of the notch width on notched Macs.
        let width: CGFloat
        if let left = screen.auxiliaryTopLeftArea?.width,
           let right = screen.auxiliaryTopRightArea?.width {
            width = max(screen.frame.width - left - right, 180)
        } else {
            width = 200
        }
        return CGSize(width: width, height: height)
    }

    private func debugLogIfRequested() {
        guard ProcessInfo.processInfo.environment["NQ_DEBUG_VITALS"] == "1" else { return }
        vitals.$snapshot
            .sink { s in
                let battery = s.batteryFraction.map { String(format: "%.0f%%", $0 * 100) } ?? "n/a"
                let names = s.topProcesses.map { "\($0.name) \(Int($0.cpuPercent))%" }.joined(separator: ", ")
                FileHandle.standardError.write(Data(
                    "[vitals] battery=\(battery) cpu=\(Int(s.cpuFraction * 100))% mem=\(Int(s.memoryUsedFraction * 100))% top=[\(names)]\n".utf8
                ))
            }
            .store(in: &cancellables)
    }
}
