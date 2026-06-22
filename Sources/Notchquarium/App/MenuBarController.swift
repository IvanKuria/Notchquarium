import AppKit

/// The status-bar item (a little fish) and its menu.
@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onToggle: () -> Void

    init(onToggle: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onToggle = onToggle
        super.init()

        statusItem.button?.title = "🐠"

        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Tank", action: #selector(toggle), keyEquivalent: "t")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Notchquarium", action: #selector(quit), keyEquivalent: "q")
            .target = self
        statusItem.menu = menu
    }

    @objc private func toggle() { onToggle() }
    @objc private func quit() { NSApp.terminate(nil) }
}
