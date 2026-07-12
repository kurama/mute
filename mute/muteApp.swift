import AppKit

@main
final class MuteApp: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var mediaMonitor: MediaMonitor?
    private var focusController: FocusController?
    private var onboardingController: OnboardingWindowController?

    static func main() {
        let app = NSApplication.shared
        let delegate = MuteApp()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
            startApp()
        } else {
            NSApp.setActivationPolicy(.regular)
            onboardingController = OnboardingWindowController.show { [weak self] in
                guard self?.onboardingController != nil else { return }
                self?.onboardingController = nil
                self?.startApp()
            }
        }
    }

    private func startApp() {
        NSApp.setActivationPolicy(.accessory)

        let fc = FocusController()
        let mm = MediaMonitor()
        let sb = StatusBarController(mediaMonitor: mm, focusController: fc)

        focusController = fc
        mediaMonitor = mm
        statusBarController = sb

        fc.setup()
        mm.onStateChange = { [weak fc, weak sb] isActive in
            fc?.handleMediaState(isActive: isActive)
            sb?.updateState(isActive: isActive)
        }

        mm.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusController?.restoreState()
    }
}
