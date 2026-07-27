import Foundation

/// Where the panel appears when opened. `notch` merges it into the display notch
/// (default); `floating` is a compact, movable panel — it first appears under the
/// status bar icon but can be dragged anywhere, for people who already run another
/// notch app.
enum PanelPosition: String {
    case notch
    case floating

    static var current: PanelPosition {
        PanelPosition(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.panelPosition) ?? "") ?? .notch
    }

    /// Width of the compact floating panel (the notch layout is much wider).
    static let floatingWidth: CGFloat = 280
}
