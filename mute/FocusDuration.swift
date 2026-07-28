import Foundation

/// The quick-pick Focus durations offered in both the panel's Focus menu and the
/// settings pane, so the two lists (and their labels) can't drift apart.
enum FocusPreset {
    static let all: [(minutes: Int, label: String)] = [
        (5, "5 min"),
        (15, "15 min"),
        (30, "30 min"),
        (60, "1 hour"),
    ]
}

extension Int {
    /// A minute count formatted for display, e.g. `45` → "45 min", `60` → "1h",
    /// `90` → "1h 30m". Shared by the panel's Focus menu and the settings pane.
    var focusDurationLabel: String {
        if self < 60 { return "\(self) min" }
        let hours = self / 60, mins = self % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
}
