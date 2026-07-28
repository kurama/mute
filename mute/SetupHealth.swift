import AVFoundation
import AppKit

/// Checks for the two things that silently break Mute: camera access being denied
/// and the Do Not Disturb automation shortcuts not being installed. Used by the
/// settings screen to surface an actionable warning instead of failing quietly.
enum SetupHealth {

    /// True only when camera access is actively denied or restricted. `.notDetermined`
    /// isn't a problem — the monitor asks for access the first time the camera is used.
    static var cameraAccessDenied: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: return true
        default: return false
        }
    }

    static func openCameraPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Reports whether both "Mute On" and "Mute Off" exist in the user's Shortcuts
    /// library. Errs on the side of "installed" if the check can't run, so a failed
    /// probe never shows a false warning. The completion is called on the main queue.
    static func detectAutomationShortcuts(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let installed = automationShortcutsInstalled()
            DispatchQueue.main.async { completion(installed) }
        }
    }

    private static func automationShortcutsInstalled() -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        proc.arguments = ["list"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do {
            try proc.run()
        } catch {
            return true // can't tell — don't nag
        }
        proc.waitUntilExit()
        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return true
        }
        let names = Set(output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
        return names.contains("Mute On") && names.contains("Mute Off")
    }
}
