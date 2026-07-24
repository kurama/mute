import Foundation
import Observation

@Observable
final class NotchPanelViewModel {
    var isMicActive = false
    var isCameraActive = false
    var isActive = false
    var isMonitoringEnabled = true
    var isSnoozed = false
    private(set) var activeSince: Date?

    func update(from monitor: MediaMonitor) {
        if monitor.isActive && !isActive { activeSince = Date() }
        else if !monitor.isActive { activeSince = nil }
        isMicActive = monitor.isMicActive
        isCameraActive = monitor.isCameraActive
        isActive = monitor.isActive
        isMonitoringEnabled = monitor.isMonitoringEnabled
        isSnoozed = monitor.isSnoozed
    }

    var dndDuration: String {
        guard let since = activeSince else { return "" }
        let minutes = Int(Date().timeIntervalSince(since) / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}
