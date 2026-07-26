import AppKit
import KeyboardShortcuts

@main
final class MuteApp: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var mediaMonitor: MediaMonitor?
    private var focusController: FocusController?
    private var onboardingController: OnboardingWindowController?
    private var notchPanel: NotchPanelWindow?
    private var notchPanelVM: NotchPanelViewModel?
    private var settingsWindow: SettingsWindowController?

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
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        let sb = StatusBarController(mediaMonitor: mm, focusController: fc, notchPanel: panel)
        sb.onOpenSettings = { [weak self] in self?.openSettings() }

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
            isActive ? SoundFeedback.playDndOn() : SoundFeedback.playDndOff()
        }
        mm.onMonitoringChange = { [weak mm, weak vm] in
            if let mm, let vm { vm.update(from: mm) }
        }

        mm.start()

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak panel] in panel?.toggle() }
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController.make(
                triggerMode: mediaMonitor?.triggerMode ?? .micAndCamera,
                onTriggerModeChange: { [weak self] mode in self?.mediaMonitor?.triggerMode = mode }
            )
        }
        settingsWindow?.present()
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusController?.restoreState()
    }
}
