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
        UserDefaults.standard.register(defaults: [
            "soundFeedbackEnabled": true,
            "defaultFocusMinutes": 30,
            "panelDismissOnOutsideClick": true,
        ])

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
            if UserDefaults.standard.bool(forKey: "soundFeedbackEnabled") {
                isActive ? SoundFeedback.playDndOn() : SoundFeedback.playDndOff()
            }
        }
        mm.onMonitoringChange = { [weak mm, weak vm] in
            if let mm, let vm { vm.update(from: mm) }
        }

        mm.start()

        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak panel] in panel?.toggle() }
        KeyboardShortcuts.onKeyUp(for: .toggleMonitoring) { [weak mm, weak fc] in
            guard let mm else { return }
            mm.isMonitoringEnabled.toggle()
            if !mm.isMonitoringEnabled { fc?.disable() }
        }
        KeyboardShortcuts.onKeyUp(for: .toggleFocus) { [weak mm] in
            guard let mm else { return }
            if mm.isFocusing {
                mm.endFocus()
            } else {
                let minutes = max(1, UserDefaults.standard.integer(forKey: "defaultFocusMinutes"))
                mm.startFocus(for: TimeInterval(minutes * 60))
            }
        }
    }

    private func openSettings() {
        // If it's already on screen just focus it; otherwise rebuild so the panes
        // reflect the current state (launch-at-login, trigger mode) rather than
        // stale @State from a previous open.
        if let wc = settingsWindow, wc.window?.isVisible == true {
            wc.present()
            return
        }
        settingsWindow = SettingsWindowController.make(
            triggerMode: mediaMonitor?.triggerMode ?? .micAndCamera,
            onTriggerModeChange: { [weak self] mode in self?.mediaMonitor?.triggerMode = mode },
            onReplayOnboarding: { [weak self] in self?.replayOnboarding() }
        )
        settingsWindow?.present()
    }

    private func replayOnboarding() {
        settingsWindow?.close()
        NSApp.setActivationPolicy(.regular)
        let wc = OnboardingWindowController.show(terminatesOnClose: false) { [weak self] in
            self?.onboardingController = nil
            NSApp.setActivationPolicy(.accessory)
        }
        wc.onDismiss = { [weak self] in
            self?.onboardingController = nil
            NSApp.setActivationPolicy(.accessory)
        }
        onboardingController = wc
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        focusController?.restoreState()
    }
}
