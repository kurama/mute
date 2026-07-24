import Foundation
import Observation

@Observable
final class NotchPanelViewModel {
    var isMicActive = false
    var isCameraActive = false
    var isActive = false
    var isMonitoringEnabled = true
    var isSnoozed = false
    var triggerMode: TriggerMode = .micAndCamera
    private(set) var activeSince: Date?
    private(set) var snoozeEndsAt: Date?

    func update(from monitor: MediaMonitor) {
        if monitor.isActive && !isActive { activeSince = Date() }
        else if !monitor.isActive { activeSince = nil }
        isMicActive = monitor.isMicActive
        isCameraActive = monitor.isCameraActive
        isActive = monitor.isActive
        isMonitoringEnabled = monitor.isMonitoringEnabled
        isSnoozed = monitor.isSnoozed
        snoozeEndsAt = monitor.snoozeEndsAt
        triggerMode = monitor.triggerMode
    }

    var snoozeRemaining: String {
        guard let end = snoozeEndsAt else { return "" }
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
