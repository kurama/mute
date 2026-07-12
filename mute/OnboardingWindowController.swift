import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    var onComplete: (() -> Void)?

    static func show(onComplete: @escaping () -> Void) -> OnboardingWindowController {
        let wc = OnboardingWindowController()
        wc.onComplete = onComplete

        let view = OnboardingView { [weak wc] in wc?.complete() }
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        window.setContentSize(NSSize(width: 580, height: 460))
        window.minSize = NSSize(width: 580, height: 460)
        window.maxSize = NSSize(width: 580, height: 460)
        window.center()
        window.isReleasedWhenClosed = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        wc.window = window
        window.delegate = wc
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return wc
    }

    func complete() {
        let cb = onComplete
        onComplete = nil
        window?.delegate = nil
        close()
        cb?()
    }

    func windowWillClose(_ notification: Notification) {
        onComplete = nil
        NSApp.terminate(nil)
    }
}
