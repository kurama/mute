import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let barItem: NSStatusItem
    private weak var panel: PanelWindow?
    var onOpenSettings: (() -> Void)?

    init(panel: PanelWindow) {
        self.panel = panel
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
        // Left-click opens the panel (at the notch or floating, per the setting);
        // right-click shows the menu — like any other menu bar app.
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            panel?.toggle()
            return
        }
        let menu = buildMenu()
        menu.delegate = self
        barItem.menu = menu
        barItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        barItem.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

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
        return menu
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
