import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let barItem: NSStatusItem
    private weak var panel: PanelWindow?
    private let viewModel: PanelViewModel
    var onOpenSettings: (() -> Void)?
    var onToggle: (() -> Void)?
    var onFocus: ((TimeInterval) -> Void)?

    init(panel: PanelWindow, viewModel: PanelViewModel) {
        self.panel = panel
        self.viewModel = viewModel
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

    /// The icon's frame in screen coordinates, so the panel can anchor under it.
    var statusItemScreenFrame: NSRect? {
        guard let button = barItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func setIcon(isActive: Bool) {
        guard let button = barItem.button else { return }
        guard let url = Bundle.main.url(forResource: "StatusBarIcon", withExtension: "svg"),
              let img = NSImage(contentsOf: url) else { return }
        let size = NSSize(width: 16, height: 16)
        if isActive {
            button.image = img.filled(with: .muteBlue, size: size)
        } else {
            img.isTemplate = true
            img.size = size
            button.image = img
        }
        button.contentTintColor = nil
        button.setAccessibilityLabel(isActive ? "Mute — Do Not Disturb on" : "Mute — Do Not Disturb off")
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        // Left-click runs the primary action (open a panel, or drop the full action
        // menu in "menu" mode); right-click always shows the compact app menu.
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            primaryAction()
            return
        }
        show(buildMenu())
    }

    /// What the icon does on left-click and on the "Show / hide the panel" shortcut.
    func primaryAction() {
        if PanelPosition.current == .menu {
            show(buildActionMenu())
        } else {
            panel?.toggle()
        }
    }

    // Popping a menu from code: attach it, click, then detach in menuDidClose so a
    // plain left-click still runs primaryAction() the rest of the time.
    private func show(_ menu: NSMenu) {
        menu.delegate = self
        barItem.menu = menu
        barItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        barItem.menu = nil
    }

    /// The full menu shown in "menu" mode: current state, the same actions the panel
    /// offers (toggle / focus), then the app menu — so no panel is ever needed.
    private func buildActionMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        if viewModel.isFocusing {
            addItem(to: menu, title: "End Focus", action: #selector(toggle))
        } else if viewModel.isMonitoringEnabled {
            addItem(to: menu, title: "Disable Mute", action: #selector(toggle))
            menu.addItem(focusMenuItem())
        } else {
            addItem(to: menu, title: "Enable Mute", action: #selector(toggle))
        }

        menu.addItem(.separator())
        appendAppItems(to: menu)
        return menu
    }

    private var statusLine: String {
        if viewModel.isFocusing { return "Focus · \(viewModel.focusRemaining)" }
        if viewModel.isActive { return "Do Not Disturb · \(viewModel.dndDuration)" }
        if !viewModel.isMonitoringEnabled { return "Mute disabled" }
        return "Do Not Disturb off"
    }

    // A parent item can't carry its own action alongside a submenu (clicking it just
    // opens the submenu), so the default duration lives inside the submenu — same
    // layout as the panel's Focus dropdown: default on top, then the presets.
    private func focusMenuItem() -> NSMenuItem {
        let submenu = NSMenu()

        let minutes = max(1, UserDefaults.standard.integer(forKey: DefaultsKey.defaultFocusMinutes))
        let def = focusItem(title: "Focus for \(minutes.focusDurationLabel)", duration: TimeInterval(minutes * 60))
        submenu.addItem(def)
        submenu.addItem(.separator())
        for preset in FocusPreset.all {
            submenu.addItem(focusItem(title: preset.label, duration: TimeInterval(preset.minutes * 60)))
        }

        let parent = NSMenuItem(title: "Focus", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        return parent
    }

    private func focusItem(title: String, duration: TimeInterval) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(startFocus(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = duration
        return item
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        appendAppItems(to: menu)
        return menu
    }

    private func appendAppItems(to menu: NSMenu) {
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        #if DEBUG
        let resetItem = NSMenuItem(title: "Reset Onboarding", action: #selector(resetOnboarding), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        menu.addItem(.separator())
        #endif

        menu.addItem(NSMenuItem(title: "Quit Mute", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func toggle() {
        onToggle?()
    }

    @objc private func startFocus(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        onFocus?(duration)
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    #if DEBUG
    @objc private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.onboardingCompleted)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.shortcutsInstalled)
    }
    #endif
}
