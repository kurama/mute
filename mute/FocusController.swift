import AppKit
import os.log

private let log = Logger(subsystem: "kurama.mute", category: "focus")

final class FocusController {

    // Mirrored to UserDefaults so a later launch can tell whether a previous
    // session left Do Not Disturb on that it never got to turn back off.
    private var enabledByUs = false {
        didSet { UserDefaults.standard.set(enabledByUs, forKey: DefaultsKey.dndOwnedByApp) }
    }
    private static let queue = DispatchQueue(label: "kurama.mute.focus", qos: .userInitiated)
    // Separate from `queue`: the install probe can block for up to ~30s per
    // shortcut waiting on the user. It must never share a serial queue with
    // run(_:) — that would delay DND toggling behind a still-running install.
    private static let installQueue = DispatchQueue(label: "kurama.mute.focus.install", qos: .userInitiated)
    private static let installedDefaultsKey = DefaultsKey.shortcutsInstalled

    func setup() {
        reconcileStaleState()
        guard !UserDefaults.standard.bool(forKey: Self.installedDefaultsKey) else { return }
        Self.installQueue.asyncAfter(deadline: .now() + 1) {
            Self.installShortcuts()
        }
    }

    // A previous session may have left DND on: a crash or force-quit skips
    // applicationWillTerminate, and there's no public API to read the system state
    // back. At launch no media session is active yet, so if we still "own" DND from
    // last time, turn it back off.
    private func reconcileStaleState() {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.dndOwnedByApp) else { return }
        run("Mute Off")
        enabledByUs = false
    }

    /// Re-run the shortcut import (opens the .shortcut files in the Shortcuts app),
    /// regardless of the installed flag — used by the settings health warning.
    /// `completion` is called on the main queue once both shortcuts have been
    /// verified (or the user gave up), so the caller can refresh its warning state.
    func reinstallShortcuts(completion: (() -> Void)? = nil) {
        Self.installQueue.async {
            Self.installShortcuts()
            if let completion { DispatchQueue.main.async(execute: completion) }
        }
    }

    private static func installShortcuts() {
        let alreadyInstalled = SetupHealth.installedShortcutNames() ?? []
        var allInstalled = true
        for name in ["Mute On", "Mute Off"] {
            if alreadyInstalled.contains(name) { continue }
            guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else {
                log.debug("Missing bundle resource: \(name).shortcut")
                allInstalled = false
                continue
            }
            NSWorkspace.shared.open(url)
            if !SetupHealth.waitForShortcutInstall(named: name) {
                allInstalled = false
            }
        }
        // Only mark installed once both are verified — an unconditional write here
        // is what let a cancelled import silently pass as configured (issue #42).
        if allInstalled {
            UserDefaults.standard.set(true, forKey: installedDefaultsKey)
        }
    }

    func handleMediaState(isActive: Bool) {
        if isActive {
            guard !enabledByUs else { return }
            enabledByUs = true
            run("Mute On")
        } else {
            guard enabledByUs else { return }
            enabledByUs = false
            run("Mute Off")
        }
    }

    func disable() {
        guard enabledByUs else { return }
        enabledByUs = false
        run("Mute Off")
    }

    func restoreState() {
        guard enabledByUs else { return }
        enabledByUs = false
        // Run synchronously: applicationWillTerminate returns straight into exit, so
        // an async dispatch here would be killed before "Mute Off" actually runs.
        Self.execute("Mute Off")
    }

    private func run(_ shortcut: String) {
        Self.queue.async { Self.execute(shortcut) }
    }

    private static func execute(_ shortcut: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        proc.arguments = ["run", shortcut]
        let pipe = Pipe()
        proc.standardError = pipe
        try? proc.run()
        proc.waitUntilExit()
        let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !err.isEmpty { log.debug("shortcuts run '\(shortcut)': \(err)") }
    }
}
