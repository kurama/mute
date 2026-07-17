import AppKit
import os.log

private let log = Logger(subsystem: "kurama.mute", category: "focus")

final class FocusController {

    private var enabledByUs = false
    private static let queue = DispatchQueue(label: "kurama.mute.focus", qos: .userInitiated)
    private static let installedDefaultsKey = "shortcutsInstalled"

    func setup() {
        guard !UserDefaults.standard.bool(forKey: Self.installedDefaultsKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Self.installShortcuts()
        }
    }

    private static func installShortcuts() {
        for name in ["Mute On", "Mute Off"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else {
                log.debug("Missing bundle resource: \(name).shortcut")
                continue
            }
            NSWorkspace.shared.open(url)
            Thread.sleep(forTimeInterval: 1.2)
        }
        UserDefaults.standard.set(true, forKey: installedDefaultsKey)
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

    func restoreState() { disable() }


    private func run(_ shortcut: String) {
        Self.queue.async {
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
}
