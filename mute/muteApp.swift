import AppKit
import ServiceManagement

@main
final class MuteApp: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var mediaMonitor: MediaMonitor?
    private var focusController: FocusController?
    private var onboardingController: OnboardingWindowController?
    private var notchPanel: NotchPanelWindow?
    private var notchPanelVM: NotchPanelViewModel?

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
        let vm = NotchPanelViewModel()
        let panel = NotchPanelWindow(
            viewModel: vm,
            onToggle: { [weak mm, weak fc] in
                guard let mm else { return }
                if mm.isFocusing {
                    mm.endFocus()
                } else {
                    mm.isMonitoringEnabled.toggle()
                    if !mm.isMonitoringEnabled { fc?.disable() }
                }
            },
            onFocus: { [weak mm] duration in mm?.startFocus(for: duration) },
            onTriggerModeChange: { [weak mm] mode in mm?.triggerMode = mode },
            onLaunchAtLoginChange: { enabled -> Bool in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    NSLog("Mute: launch at login \(enabled ? "register" : "unregister") failed: \(error)")
                }
                // Return the real resulting state so the UI can reflect a silent failure.
                return SMAppService.mainApp.status == .enabled
            }
        )
        let sb = StatusBarController(mediaMonitor: mm, focusController: fc, notchPanel: panel)

        focusController = fc
        mediaMonitor = mm
        statusBarController = sb
        notchPanel = panel
        notchPanelVM = vm

        fc.setup()

        mm.onStateChange = { [weak fc, weak sb, weak mm, weak vm] isActive in
            fc?.handleMediaState(isActive: isActive)
            sb?.updateState(isActive: isActive)
            if let mm, let vm { vm.update(from: mm) }
        }
        mm.onMonitoringChange = { [weak mm, weak vm] in
            if let mm, let vm { vm.update(from: mm) }
        }

        mm.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusController?.restoreState()
    }
}
