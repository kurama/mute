import Foundation

/// What clicking the menu bar icon does. `menu` (default) opens a plain native menu
/// with no panel — the lightweight, classic menu bar app experience. `notch` merges
/// a panel into the display notch; `floating` is a compact, movable panel that first
/// appears under the status bar icon but can be dragged anywhere, for people who
/// already run another notch app.
enum PanelPosition: String {
    case menu
    case notch
    case floating

    static var current: PanelPosition {
        PanelPosition(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.panelPosition) ?? "") ?? .menu
    }

    /// Width of the compact floating panel (the notch layout is much wider).
    static let floatingWidth: CGFloat = 280

    /// Width of the wide notch layout that flows out from under the menu bar.
    static let notchWidth: CGFloat = 644

    /// Height of the notch layout's main content area, below the header row.
    static let notchBodyHeight: CGFloat = 88

    /// Header height used by the notch layout on displays without a physical notch,
    /// so it still renders its indicator row instead of collapsing to nothing.
    static let fallbackNotchHeight: CGFloat = 32
}
