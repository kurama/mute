import AppKit
import os.log

private let log = Logger(subsystem: "kurama.mute", category: "focus")

enum FocusAutomationState: Equatable {
    case inactive
    case checking
    case ownedByMute
    case preservedExistingFocus
    case unavailable
}

final class FocusController {

    static let startShortcut = "Mute Start Focus"
    static let endShortcut = "Mute End Focus"
    static let currentFocusShortcut = "Mute Current Focus"
    static let automationVersion = 3

    static func bundledShortcutURL(named name: String) -> URL? {
        let resource: String
        switch name {
        case startShortcut: resource = "Mute Start Focus"
        case endShortcut: resource = "Mute End Focus"
        case currentFocusShortcut: resource = "Mute Current Focus"
        default: return nil
        }
        return Bundle.main.url(forResource: resource, withExtension: "shortcut", subdirectory: "ShortcutSources")
    }

    var onStateChange: ((FocusAutomationState, FocusAutomationState) -> Void)?

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
    private var transitionID = 0
    private var mediaIsActive = false
    private(set) var state: FocusAutomationState = .inactive {
        didSet {
            guard oldValue != state else { return }
            onStateChange?(oldValue, state)
        }
    }

    func setup() {
        reconcileStaleState()
        guard !automationIsCurrent else { return }
        Self.installQueue.asyncAfter(deadline: .now() + 1) {
            Self.installShortcuts()
        }
    }

    // Ownership alone cannot tell whether the user changed Focus after a crash.
    private func reconcileStaleState() {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.dndOwnedByApp) else { return }
        enabledByUs = false
        log.notice("Discarded stale Focus ownership after launch without changing system Focus")
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
        for name in [startShortcut, endShortcut, currentFocusShortcut] {
            if alreadyInstalled.contains(name) { continue }
            guard let url = bundledShortcutURL(named: name) else {
                log.debug("Missing bundle resource: \(name).shortcut")
                allInstalled = false
                continue
            }
            NSWorkspace.shared.open(url)
            if !SetupHealth.waitForShortcutInstall(named: name) {
                allInstalled = false
            }
        }
        // Only mark installed once all shortcuts are verified — an unconditional write here
        // is what let a cancelled import silently pass as configured (issue #42).
        if allInstalled {
            UserDefaults.standard.set(true, forKey: installedDefaultsKey)
            UserDefaults.standard.set(automationVersion, forKey: DefaultsKey.automationVersion)
        }
    }

    func handleMediaState(isActive: Bool) {
        mediaIsActive = isActive
        transitionID += 1
        let id = transitionID
        if isActive {
            guard !enabledByUs, state != .checking else { return }
            guard automationIsCurrent else {
                state = .unavailable
                return
            }
            state = .checking
            Self.queue.async { [weak self] in
                let currentFocus = Self.execute(Self.currentFocusShortcut).standardOutput
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let startResult = currentFocus.isEmpty ? Self.execute(Self.startShortcut) : nil
                DispatchQueue.main.async {
                    guard let self, self.transitionID == id, self.mediaIsActive else { return }
                    if !currentFocus.isEmpty {
                        self.state = .preservedExistingFocus
                    } else if startResult?.succeeded == true {
                        self.enabledByUs = true
                        self.state = .ownedByMute
                    } else {
                        self.state = .unavailable
                        log.error("Could not enable Focus automation")
                    }
                }
            }
        } else {
            endSession()
        }
    }

    func disable() {
        transitionID += 1
        mediaIsActive = false
        endSession()
    }

    private var automationIsCurrent: Bool {
        UserDefaults.standard.integer(forKey: DefaultsKey.automationVersion) == Self.automationVersion
    }

    private func endSession() {
        let shouldDisable = enabledByUs
        enabledByUs = false
        state = .inactive
        guard shouldDisable else { return }
        // The shortcut targets DND by its stable identifier; it does not turn off a
        // Work, Sleep, or custom Focus selected by the user during the call.
        run(Self.endShortcut)
    }

    func restoreState() {
        guard enabledByUs else { return }
        enabledByUs = false
        // Run synchronously: applicationWillTerminate returns straight into exit, so
        // an async dispatch here would be killed before "Mute Off" actually runs.
        _ = Self.execute(Self.endShortcut)
    }

    private func run(_ shortcut: String) {
        Self.queue.async { _ = Self.execute(shortcut) }
    }

    private struct ShortcutResult {
        let succeeded: Bool
        let standardOutput: String
    }

    @discardableResult
    private static func execute(_ shortcut: String) -> ShortcutResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        proc.arguments = ["run", shortcut]
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        proc.standardError = errorPipe
        proc.standardOutput = outputPipe
        do {
            try proc.run()
        } catch {
            log.error("Could not run shortcut '\(shortcut)': \(error.localizedDescription)")
            return ShortcutResult(succeeded: false, standardOutput: "")
        }
        proc.waitUntilExit()
        let err = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !err.isEmpty { log.debug("shortcuts run '\(shortcut)': \(err)") }
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ShortcutResult(succeeded: proc.terminationStatus == 0, standardOutput: output)
    }
}
