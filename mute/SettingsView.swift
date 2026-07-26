import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct GeneralSettings: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch Mute at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    guard newValue != (SMAppService.mainApp.status == .enabled) else { return }
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        NSLog("Mute: launch at login toggle failed: \(error)")
                    }
                    // Snap back to the real state if the change failed.
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
}

struct TriggerSettings: View {
    @State var mode: TriggerMode
    let onChange: (TriggerMode) -> Void

    var body: some View {
        Form {
            Picker("Activate Do Not Disturb on", selection: $mode) {
                Text("Microphone & Camera").tag(TriggerMode.micAndCamera)
                Text("Microphone only").tag(TriggerMode.micOnly)
                Text("Camera only").tag(TriggerMode.cameraOnly)
            }
            .pickerStyle(.inline)
            .onChange(of: mode) { _, newValue in onChange(newValue) }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutSettings: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Show / hide the panel", name: .togglePanel)
        }
        .formStyle(.grouped)
    }
}
