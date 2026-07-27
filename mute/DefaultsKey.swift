import Foundation

/// Keys for values persisted in `UserDefaults`, kept in one place so the raw
/// strings are never duplicated (and mistyped) across the app.
enum DefaultsKey {
    static let onboardingCompleted = "onboardingCompleted"
    static let shortcutsInstalled = "shortcutsInstalled"
    static let triggerMode = "triggerMode"
    static let soundFeedbackEnabled = "soundFeedbackEnabled"
    static let defaultFocusMinutes = "defaultFocusMinutes"
    static let panelDismissOnOutsideClick = "panelDismissOnOutsideClick"
    static let panelPosition = "panelPosition"
    static let panelFloatingOrigin = "panelFloatingOrigin"
}
