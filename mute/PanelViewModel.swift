import CoreGraphics
import Foundation
import Observation

@Observable
final class PanelViewModel {
    var isMicActive = false
    var isCameraActive = false
    var isActive = false
    var isMonitoringEnabled = true
    var isFocusing = false
    var triggerMode: TriggerMode = .micAndCamera
    /// Notch height of the screen the panel is currently shown on. Updated on every
    /// open so the notch layout follows the display it lands on (which may differ
    /// from the one the window was built on).
    var notchHeight: CGFloat = PanelPosition.fallbackNotchHeight
    private(set) var activeSince: Date?
    private(set) var focusEndsAt: Date?

    func update(from monitor: MediaMonitor) {
        if monitor.isActive && !isActive { activeSince = Date() }
        else if !monitor.isActive { activeSince = nil }
        isMicActive = monitor.isMicActive
        isCameraActive = monitor.isCameraActive
        isActive = monitor.isActive
        isMonitoringEnabled = monitor.isMonitoringEnabled
        isFocusing = monitor.isFocusing
        focusEndsAt = monitor.focusEndsAt
        triggerMode = monitor.triggerMode
    }

    var focusRemaining: String {
        guard let end = focusEndsAt else { return "" }
        let remaining = max(0, Int(end.timeIntervalSinceNow))
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var dndDuration: String {
        guard let since = activeSince else { return "" }
        let elapsed = Int(Date().timeIntervalSince(since))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let s = elapsed % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
