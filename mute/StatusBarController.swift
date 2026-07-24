import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let barItem: NSStatusItem
    private let mediaMonitor: MediaMonitor
    private let focusController: FocusController
    private weak var notchPanel: NotchPanelWindow?

    init(mediaMonitor: MediaMonitor, focusController: FocusController, notchPanel: NotchPanelWindow) {
        self.mediaMonitor = mediaMonitor
        self.focusController = focusController
        self.notchPanel = notchPanel
        barItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        setIcon(isActive: false)
        barItem.button?.action = #selector(handleClick(_:))
        barItem.button?.target = self
        barItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func updateState(isActive: Bool) {
        setIcon(isActive: isActive)
    }

    private func setIcon(isActive: Bool) {
        guard let button = barItem.button else { return }
        guard let url = Bundle.main.url(forResource: "StatusBarIcon", withExtension: "svg"),
              let img = NSImage(contentsOf: url) else { return }
        let size = NSSize(width: 16, height: 16)
        if isActive {
            button.image = img.filled(with: .systemGreen, size: size)
        } else {
            img.isTemplate = true
            img.size = size
            button.image = img
        }
        button.contentTintColor = nil
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = buildMenu()
            menu.delegate = self
            barItem.menu = menu
            barItem.button?.performClick(nil)
        } else {
            notchPanel?.toggle()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        barItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let isActive = mediaMonitor.isActive

        let statusLine: String
        if isActive {
            var parts: [String] = []
            if mediaMonitor.isMicActive { parts.append("mic") }
            if mediaMonitor.isCameraActive { parts.append("camera") }
            statusLine = "Active (\(parts.joined(separator: " + "))) — DND on"
        } else if mediaMonitor.isSnoozed {
            statusLine = "Snoozed"
        } else {
            statusLine = mediaMonitor.isMonitoringEnabled ? "Idle — monitoring" : "Disabled"
        }

        let statusItem = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        let toggleTitle: String
        if mediaMonitor.isSnoozed {
            toggleTitle = "Cancel Snooze"
        } else {
            toggleTitle = mediaMonitor.isMonitoringEnabled ? "Disable Mute" : "Enable Mute"
        }
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let triggerItem = NSMenuItem(title: "Trigger on", action: nil, keyEquivalent: "")
        let triggerSubmenu = NSMenu(title: "Trigger on")
        let modes: [(title: String, mode: TriggerMode)] = [
            ("Mic & Camera", .micAndCamera),
            ("Mic only", .micOnly),
            ("Camera only", .cameraOnly),
        ]
        for (title, mode) in modes {
            let item = NSMenuItem(title: title, action: #selector(setTriggerMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode
            item.state = mediaMonitor.triggerMode == mode ? .on : .off
            triggerSubmenu.addItem(item)
        }
        triggerItem.submenu = triggerSubmenu
        menu.addItem(triggerItem)

        menu.addItem(.separator())

        #if DEBUG
        let resetItem = NSMenuItem(title: "Reset Onboarding", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        menu.addItem(.separator())
        #endif

        menu.addItem(NSMenuItem(title: "Quit Mute", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleMonitoring() {
        if mediaMonitor.isSnoozed {
            mediaMonitor.cancelSnooze()
        } else {
            mediaMonitor.isMonitoringEnabled.toggle()
            if !mediaMonitor.isMonitoringEnabled { focusController.disable() }
        }
        setIcon(isActive: mediaMonitor.isActive)
    }

    @objc private func setTriggerMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? TriggerMode else { return }
        mediaMonitor.triggerMode = mode
    }

    #if DEBUG
    @objc private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "shortcutsInstalled")
    }
    #endif
}
