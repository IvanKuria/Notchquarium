import AppKit

// Notchquarium runs as a menu-bar/agent app: no Dock icon.
// Top-level entry runs on the main thread; assert that to satisfy the
// main-actor isolation of AppDelegate/SystemVitals under Swift 6 concurrency.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
