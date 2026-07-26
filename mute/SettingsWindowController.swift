import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable {
    case general, triggers, shortcuts

    var title: String {
        switch self {
        case .general: "General"
        case .triggers: "Triggers"
        case .shortcuts: "Shortcuts"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .triggers: "mic"
        case .shortcuts: "keyboard"
        }
    }

    var identifier: NSToolbarItem.Identifier { NSToolbarItem.Identifier(rawValue) }
}

/// Preferences-style settings window: tabs live in the titlebar via an
/// NSToolbar (`.preference` style), and the pane below is swapped per tab —
/// the native macOS look, without the "window inside a window" effect a
/// SwiftUI TabView produces here.
final class SettingsWindowController: NSWindowController, NSToolbarDelegate, NSWindowDelegate {
    private var triggerMode: TriggerMode
    private let onTriggerModeChange: (TriggerMode) -> Void

    static func make(
        triggerMode: TriggerMode,
        onTriggerModeChange: @escaping (TriggerMode) -> Void
    ) -> SettingsWindowController {
        SettingsWindowController(triggerMode: triggerMode, onTriggerModeChange: onTriggerModeChange)
    }

    init(triggerMode: TriggerMode, onTriggerModeChange: @escaping (TriggerMode) -> Void) {
        self.triggerMode = triggerMode
        self.onTriggerModeChange = onTriggerModeChange

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Mute Settings"
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .preference
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()

        super.init(window: window)
        window.delegate = self

        let toolbar = NSToolbar(identifier: "MuteSettingsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier = SettingsTab.general.identifier
        window.toolbar = toolbar

        select(.general)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        // A menu bar (.accessory) app has no windows; switch to .regular so the
        // settings window can take focus, then drop back to .accessory on close.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func select(_ tab: SettingsTab) {
        let pane: AnyView
        switch tab {
        case .general:
            pane = AnyView(GeneralSettings())
        case .triggers:
            pane = AnyView(TriggerSettings(mode: triggerMode) { [weak self] mode in
                self?.triggerMode = mode
                self?.onTriggerModeChange(mode)
            })
        case .shortcuts:
            pane = AnyView(ShortcutSettings())
        }
        window?.contentView = NSHostingView(rootView: pane.frame(width: 460, height: 190))
    }

    @objc private func toolbarItemSelected(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab(rawValue: sender.itemIdentifier.rawValue) else { return }
        select(tab)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let tab = SettingsTab(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.title
        item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
        item.target = self
        item.action = #selector(toolbarItemSelected(_:))
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsTab.allCases.map(\.identifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}
