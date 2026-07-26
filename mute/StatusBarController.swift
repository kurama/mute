import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private let barItem: NSStatusItem
    private let mediaMonitor: MediaMonitor
    private let focusController: FocusController
    private weak var notchPanel: NotchPanelWindow?
    var onOpenSettings: (() -> Void)?

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
            button.image = img.filled(with: NSColor(red: 42/255, green: 90/255, blue: 210/255, alpha: 1), size: size)
        } else {
            img.isTemplate = true
            img.size = size
            button.image = img
        }
        button.contentTintColor = nil
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
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

        let showItem = NSMenuItem(title: "Show Panel", action: #selector(showPanel), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
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

    @objc private func showPanel() {
        notchPanel?.show()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    #if DEBUG
    @objc private func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
        UserDefaults.standard.removeObject(forKey: "shortcutsInstalled")
    }
    #endif
}
