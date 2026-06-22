import AppKit

// Notchquarium runs as a menu-bar/agent app: no Dock icon, no main menu bar app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
