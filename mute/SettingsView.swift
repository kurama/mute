import SwiftUI
import ServiceManagement
import KeyboardShortcuts

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general, triggers, focus, shortcuts
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "General"
        case .triggers: "Triggers"
        case .focus: "Focus"
        case .shortcuts: "Shortcuts"
        }
    }
}

struct SettingsView: View {
    let initialTriggerMode: TriggerMode
    let onTriggerModeChange: (TriggerMode) -> Void
    let onReplayOnboarding: () -> Void

    @State private var tab: SettingsTab = .general
    @State private var mode: TriggerMode
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("soundFeedbackEnabled") private var soundFeedbackEnabled = true
    @AppStorage("defaultFocusMinutes") private var defaultFocusMinutes = 30

    init(
        initialTriggerMode: TriggerMode,
        onTriggerModeChange: @escaping (TriggerMode) -> Void,
        onReplayOnboarding: @escaping () -> Void
    ) {
        self.initialTriggerMode = initialTriggerMode
        self.onTriggerModeChange = onTriggerModeChange
        self.onReplayOnboarding = onReplayOnboarding
        _mode = State(initialValue: initialTriggerMode)
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                tabBar
                    .padding(.top, 22)
                    .padding(.bottom, 22)

                ZStack {
                    switch tab {
                    case .general: generalPane.transition(.opacity)
                    case .triggers: triggerPane.transition(.opacity)
                    case .focus: focusPane.transition(.opacity)
                    case .shortcuts: shortcutPane.transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.18), value: tab)
            }
        }
        .frame(width: 520, height: 340)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tab == item ? .white : .white.opacity(0.45))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(tab == item ? Color.muteBlue : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Panes

    private var generalPane: some View {
        VStack(spacing: 10) {
            card {
                row(title: "Launch at login", subtitle: "Start Mute automatically when you log in") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color.muteBlue)
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
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                }
            }
            card {
                row(title: "Sound feedback", subtitle: "Play a soft sound when Do Not Disturb turns on and off") {
                    Toggle("", isOn: $soundFeedbackEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color.muteBlue)
                }
            }
            card {
                row(title: "Replay intro", subtitle: "Show the welcome screens again") {
                    Button(action: onReplayOnboarding) {
                        Text("Replay")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private var triggerPane: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Activate Do Not Disturb on")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 8) {
                    triggerPill("Mic & Camera", .micAndCamera)
                    triggerPill("Microphone", .micOnly)
                    triggerPill("Camera", .cameraOnly)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var focusPane: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Focus duration")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text("The top option in the panel's Focus menu")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 8) {
                    durationPill(5)
                    durationPill(15)
                    durationPill(30)
                    durationPill(60)
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    Text("Custom")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(durationLabel(defaultFocusMinutes))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                    Stepper("", value: $defaultFocusMinutes, in: 1...180, step: 5)
                        .labelsHidden()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var shortcutPane: some View {
        card {
            row(title: "Show / hide the panel", subtitle: "Global keyboard shortcut") {
                KeyboardShortcuts.Recorder("", name: .togglePanel)
            }
        }
    }

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }

    private func durationPill(_ minutes: Int) -> some View {
        Button {
            defaultFocusMinutes = minutes
        } label: {
            Text(minutes < 60 ? "\(minutes) min" : "1 hour")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(defaultFocusMinutes == minutes ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(defaultFocusMinutes == minutes ? Color.muteBlue : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building blocks

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row<Control: View>(
        title: String,
        subtitle: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            control()
        }
    }

    private func triggerPill(_ title: String, _ value: TriggerMode) -> some View {
        Button {
            mode = value
            onTriggerModeChange(value)
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(mode == value ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(mode == value ? Color.muteBlue : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
