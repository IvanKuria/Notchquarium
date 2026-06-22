import AppKit
import Combine

/// Owns the app lifecycle: spins up the notch panel, the vitals poller and (in
/// later tasks) the menu-bar item.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private let vitals = SystemVitals()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        vitals.start()

        // Opt-in debug logging: NQ_DEBUG_VITALS=1 swift run Notchquarium
        if ProcessInfo.processInfo.environment["NQ_DEBUG_VITALS"] == "1" {
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

        guard let screen = NSScreen.main else { return }

        let size = CGSize(width: 300, height: 180)
        let origin = CGPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )

        let panel = NSPanel(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.orderFrontRegardless()

        self.panel = panel
    }
}
