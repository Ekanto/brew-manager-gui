import AppKit

/// When BrewManager is launched as a bare SwiftPM executable there is no
/// app bundle, so macOS registers the process as background-only. Such a
/// process can draw windows and receive mouse events, but its windows can
/// never become key, which means text fields receive no keyboard input.
/// Promoting the activation policy to `.regular` restores normal keyboard focus.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
