import AppKit
import SwiftUI

extension NSColor {
    /// Mute's accent blue (active indicators, selected pills, the active icon tint).
    static let muteBlue = NSColor(red: 42 / 255, green: 90 / 255, blue: 210 / 255, alpha: 1)
    /// The near-black backdrop shared by the settings and onboarding windows.
    static let muteBackground = NSColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
}

extension Color {
    static let muteBlue = Color(nsColor: .muteBlue)
    static let muteBackground = Color(nsColor: .muteBackground)
}
