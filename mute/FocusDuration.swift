import Foundation

extension Int {
    /// A minute count formatted for display, e.g. `45` → "45 min", `60` → "1h",
    /// `90` → "1h 30m". Shared by the panel's Focus menu and the settings pane.
    var focusDurationLabel: String {
        if self < 60 { return "\(self) min" }
        let hours = self / 60, mins = self % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
}
