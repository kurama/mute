import AppKit

final class StatusBarController {
    private let barItem: NSStatusItem
    private let mediaMonitor: MediaMonitor
    private let focusController: FocusController

    init(mediaMonitor: MediaMonitor, focusController: FocusController) {
        self.mediaMonitor = mediaMonitor
        self.focusController = focusController
        barItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(isActive: false)
        rebuildMenu(isActive: false)
    }

    func updateState(isActive: Bool) {
        setIcon(isActive: isActive)
        rebuildMenu(isActive: isActive)
    }

    // MARK: - Icon

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

    // MARK: - Menu

    private func rebuildMenu(isActive: Bool) {
        let menu = NSMenu()

        let statusLine: String
        if isActive {
            var parts: [String] = []
            if mediaMonitor.isMicActive { parts.append("mic") }
            if mediaMonitor.isCameraActive { parts.append("camera") }
            statusLine = "Active (\(parts.joined(separator: " + "))) — DND on"
        } else {
            statusLine = mediaMonitor.isMonitoringEnabled ? "Idle — monitoring" : "Disabled"
        }

        let statusItem = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        let toggleTitle = mediaMonitor.isMonitoringEnabled ? "Disable Mute" : "Enable Mute"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleMonitoring), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Trigger mode submenu
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
            item.tag = tagFor(mode)
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

        barItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleMonitoring() {
        mediaMonitor.isMonitoringEnabled.toggle()
        if !mediaMonitor.isMonitoringEnabled {
            focusController.disable()
        }
        setIcon(isActive: mediaMonitor.isActive)
        rebuildMenu(isActive: mediaMonitor.isActive)
    }

    @objc private func setTriggerMode(_ sender: NSMenuItem) {
        let mode: TriggerMode
        switch sender.tag {
        case 1:  mode = .micOnly
        case 2:  mode = .cameraOnly
        default: mode = .micAndCamera
        }
        mediaMonitor.triggerMode = mode
        rebuildMenu(isActive: mediaMonitor.isActive)
    }

    private func tagFor(_ mode: TriggerMode) -> Int {
        switch mode {
        case .micAndCamera: return 0
        case .micOnly:      return 1
        case .cameraOnly:   return 2
        }
    }

    #if DEBUG
    @objc private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "shortcutsInstalled")
    }
    #endif
}
