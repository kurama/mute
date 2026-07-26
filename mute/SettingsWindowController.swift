import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static func make(
        triggerMode: TriggerMode,
        onTriggerModeChange: @escaping (TriggerMode) -> Void
    ) -> SettingsWindowController {
        let view = SettingsView(initialTriggerMode: triggerMode, onTriggerModeChange: onTriggerModeChange)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable]
        window.title = "Mute Settings"
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()

        let wc = SettingsWindowController(window: window)
        window.delegate = wc
        return wc
    }

    func present() {
        // A menu bar (.accessory) app has no windows; switch to .regular so the
        // settings window can take focus, then drop back to .accessory on close.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
