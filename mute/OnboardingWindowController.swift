import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    var onComplete: (() -> Void)?
    var onDismiss: (() -> Void)?
    /// First run quits the app when the window is closed unfinished; a replay just dismisses.
    var terminatesOnClose = true

    static func show(terminatesOnClose: Bool = true, onComplete: @escaping () -> Void) -> OnboardingWindowController {
        let wc = OnboardingWindowController()
        wc.onComplete = onComplete
        wc.terminatesOnClose = terminatesOnClose

        let view = OnboardingView { [weak wc] in wc?.complete() }
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []

        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .muteBackground
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
        if terminatesOnClose {
            NSApp.terminate(nil)
        } else {
            let cb = onDismiss
            onDismiss = nil
            cb?()
        }
    }
}
