import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {
    let initialTriggerMode: TriggerMode
    let onTriggerModeChange: (TriggerMode) -> Void

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            TriggerSettings(mode: initialTriggerMode, onChange: onTriggerModeChange)
                .tabItem { Label("Triggers", systemImage: "mic") }
            ShortcutSettings()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .frame(width: 460, height: 200)
    }
}

private struct GeneralSettings: View {
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

private struct TriggerSettings: View {
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

private struct ShortcutSettings: View {
    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Show / hide the panel", name: .togglePanel)
        }
        .formStyle(.grouped)
    }
}
