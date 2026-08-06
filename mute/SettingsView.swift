import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {
    /// Fixed size of the settings window; shared with SettingsWindowController so
    /// the SwiftUI frame and the hosting NSWindow can't drift apart.
    static let windowSize = CGSize(width: 640, height: 600)

    let onTriggerModeChange: (TriggerMode) -> Void
    let onReplayOnboarding: () -> Void
    let onReinstallAutomation: (@escaping () -> Void) -> Void

    @State private var mode: TriggerMode
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var automationMissing = false
    @State private var isReinstallingAutomation = false
    @AppStorage(DefaultsKey.soundFeedbackEnabled) private var soundFeedbackEnabled = true
    @AppStorage(DefaultsKey.defaultFocusMinutes) private var defaultFocusMinutes = 30
    @AppStorage(DefaultsKey.panelDismissOnOutsideClick) private var panelDismissOnOutsideClick = true
    @AppStorage(DefaultsKey.panelPosition) private var panelPositionRaw = PanelPosition.menu.rawValue

    init(
        initialTriggerMode: TriggerMode,
        onTriggerModeChange: @escaping (TriggerMode) -> Void,
        onReplayOnboarding: @escaping () -> Void,
        onReinstallAutomation: @escaping (@escaping () -> Void) -> Void
    ) {
        self.onTriggerModeChange = onTriggerModeChange
        self.onReplayOnboarding = onReplayOnboarding
        self.onReinstallAutomation = onReinstallAutomation
        _mode = State(initialValue: initialTriggerMode)
    }

    private var cameraAccessDenied: Bool { mode != .micOnly && SetupHealth.cameraAccessDenied }

    var body: some View {
        ZStack {
            Color.muteBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    header

                    section("General") { generalSection }
                    section("Triggers") { triggerSection }
                    section("Focus") { focusSection }
                    section("Shortcuts") { shortcutSection }
                    section("Appearance") { appearanceSection }
                }
                .padding(40)
            }
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            SetupHealth.detectAutomationShortcuts { automationMissing = !$0 }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
            Text("Mute stays quiet, quick to reach, and out of the way.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Section layout

    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 24) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.white.opacity(0.35))
                .frame(width: 110, alignment: .leading)
                .padding(.top, 2)

            VStack(spacing: 10) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var generalSection: some View {
        if automationMissing {
            warningCard(
                title: "Automation not set up",
                subtitle: "Mute can't toggle Do Not Disturb until the “Mute On/Off” shortcuts are installed.",
                action: isReinstallingAutomation ? "Installing…" : "Install",
                perform: {
                    guard !isReinstallingAutomation else { return }
                    isReinstallingAutomation = true
                    onReinstallAutomation {
                        isReinstallingAutomation = false
                        SetupHealth.detectAutomationShortcuts { automationMissing = !$0 }
                    }
                }
            )
        }
        if cameraAccessDenied {
            warningCard(
                title: "Camera access denied",
                subtitle: "Mute can't detect camera use. Grant access in System Settings.",
                action: "Open Settings",
                perform: SetupHealth.openCameraPrivacySettings
            )
        }
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

    private var triggerSection: some View {
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

    private var focusSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Focus duration")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text("The top option in the panel's Focus menu")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                HStack(spacing: 8) {
                    ForEach(FocusPreset.all, id: \.minutes) { preset in
                        durationPill(preset.minutes, preset.label)
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    Text("Custom")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(defaultFocusMinutes.focusDurationLabel)
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

    @ViewBuilder
    private var shortcutSection: some View {
        card {
            row(title: "Show / hide the panel", subtitle: "Global keyboard shortcut") {
                KeyboardShortcuts.Recorder("", name: .togglePanel)
            }
        }
        card {
            row(title: "Turn Mute on / off", subtitle: "Turn mic & camera detection on or off") {
                KeyboardShortcuts.Recorder("", name: .toggleMonitoring)
            }
        }
        card {
            row(title: "Start / end Focus", subtitle: "Uses your default Focus duration") {
                KeyboardShortcuts.Recorder("", name: .toggleFocus)
            }
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("When you click the menu bar icon")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Menu is the simplest — a plain menu, no panel. Use a floating panel if another app already lives in the notch.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    positionPill("Menu", .menu)
                    positionPill("Notch", .notch)
                    positionPill("Floating", .floating)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The dismiss-on-outside-click behavior only applies to the panels.
        if PanelPosition(rawValue: panelPositionRaw) != .menu {
            card {
                row(title: "Dismiss when clicking outside",
                    subtitle: "Hide the panel automatically when you click elsewhere") {
                    Toggle("", isOn: $panelDismissOnOutsideClick)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color.muteBlue)
                }
            }
        }
    }

    private func positionPill(_ title: String, _ value: PanelPosition) -> some View {
        selectablePill(title, isSelected: panelPositionRaw == value.rawValue) {
            panelPositionRaw = value.rawValue
        }
    }

    private func durationPill(_ minutes: Int, _ label: String) -> some View {
        selectablePill(label, isSelected: defaultFocusMinutes == minutes) {
            defaultFocusMinutes = minutes
        }
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

    private func warningCard(title: String, subtitle: String, action: String, perform: @escaping () -> Void) -> some View {
        card {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button(action: perform) {
                    Text(action)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.muteBlue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
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
        selectablePill(title, isSelected: mode == value) {
            mode = value
            onTriggerModeChange(value)
        }
    }

    private func selectablePill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.muteBlue : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
