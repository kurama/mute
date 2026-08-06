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
        guard let names = installedShortcutNames() else { return true } // can't tell — don't nag
        return names.contains("Mute On") && names.contains("Mute Off")
    }

    /// Blocks the calling thread — call only off the main thread. Polls `shortcuts
    /// list` while the user interacts with the Shortcuts import sheet, since there's
    /// no callback for when they click "Add Shortcut". Stops as soon as Shortcuts
    /// stops being the frontmost app — that covers both "accepted" and
    /// "cancelled/closed" — so a cancel doesn't stall the caller for the full
    /// timeout. Falls back to a ~30s cap in case that focus signal is unavailable.
    static func waitForShortcutInstall(named name: String, timeout: TimeInterval = 30, pollInterval: TimeInterval = 0.5) -> Bool {
        var shortcutsWasFrontmost = false
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: pollInterval)
            if installedShortcutNames()?.contains(name) == true { return true }
            let isShortcutsFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.shortcuts"
            if isShortcutsFrontmost {
                shortcutsWasFrontmost = true
            } else if shortcutsWasFrontmost {
                break
            }
        }
        // Err on the side of "installed" only if the probe itself couldn't run at all —
        // a cancelled import must not be reported as a success.
        return installedShortcutNames()?.contains(name) ?? true
    }

    /// Lists the names of shortcuts currently in the user's Shortcuts library, via
    /// `shortcuts list`. Returns nil if the probe itself couldn't run.
    static func installedShortcutNames() -> Set<String>? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        proc.arguments = ["list"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        do {
            try proc.run()
        } catch {
            return nil
        }
        proc.waitUntilExit()
        guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
            return nil
        }
        return Set(output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) })
    }
}
