import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @State private var step = 0
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.muteBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    if step == 0 {
                        WelcomeStep(onNext: advance)
                            .transition(slideTransition)
                    } else if step == 1 {
                        ShortcutsStep(onNext: advance)
                            .transition(slideTransition)
                    } else if step == 2 {
                        AppearanceStep(onNext: advance)
                            .transition(slideTransition)
                    } else {
                        FinishStep(onComplete: onComplete)
                            .transition(slideTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)

                HStack(spacing: 7) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.white : Color.white.opacity(0.18))
                            .frame(width: i == step ? 22 : 6, height: 6)
                            .animation(.spring(response: 0.35), value: step)
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .frame(width: 580, height: 460)
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func advance() {
        withAnimation { step += 1 }
    }
}

private struct WelcomeStep: View {
    var onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                Image("OnboardingLogo")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Mute.")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 20)

            Text("Silence notifications.\nAutomatically.")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(6)
                .padding(.bottom, 14)

            Text("Zoom, Teams, Meet, FaceTime, and more.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.36))
                .padding(.bottom, 52)

            OnboardingButton(title: "Get started", action: onNext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
    }
}

private struct ShortcutsStep: View {
    var onNext: () -> Void
    @State private var muteOnInstalled = false
    @State private var muteOffInstalled = false
    @State private var isInstalling = false

    private var allInstalled: Bool { muteOnInstalled && muteOffInstalled }

    private static var alreadyInstalled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.shortcutsInstalled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("One quick step.")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 18)

            Text("Mute needs two shortcuts to control\nFocus mode on your Mac.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(5)
                .padding(.bottom, 36)

            HStack(spacing: 14) {
                ShortcutBadge(name: "Mute On", isInstalled: muteOnInstalled)
                ShortcutBadge(name: "Mute Off", isInstalled: muteOffInstalled)
            }
            .padding(.bottom, 44)

            if allInstalled || Self.alreadyInstalled {
                OnboardingButton(title: "Continue", action: onNext)
            } else {
                OnboardingButton(
                    title: isInstalling ? "Installing…" : "Install Shortcuts",
                    action: install
                )
                .disabled(isInstalling)

            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
        .onAppear {
            guard Self.alreadyInstalled else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.3)) {
                    muteOnInstalled = true
                    muteOffInstalled = true
                }
            }
        }
    }

    private func install() {
        isInstalling = true
        Task {
            for name in ["Mute On", "Mute Off"] {
                if name == "Mute On" && muteOnInstalled { continue }
                if name == "Mute Off" && muteOffInstalled { continue }
                guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else { continue }
                NSWorkspace.shared.open(url)
                let installed = await waitForShortcut(named: name)
                withAnimation(.spring(response: 0.3)) {
                    if name == "Mute On" { muteOnInstalled = installed }
                    else { muteOffInstalled = installed }
                }
            }
            isInstalling = false
            if muteOnInstalled && muteOffInstalled {
                UserDefaults.standard.set(true, forKey: DefaultsKey.shortcutsInstalled)
            }
        }
    }

    private func waitForShortcut(named name: String) async -> Bool {
        await Task.detached { SetupHealth.waitForShortcutInstall(named: name) }.value
    }
}

private struct ShortcutBadge: View {
    let name: String
    let isInstalled: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isInstalled ? 0.12 : 0.06))
                    .frame(width: 40, height: 40)

                Image(systemName: isInstalled ? "checkmark" : "bolt.fill")
                    .font(.system(size: 14, weight: isInstalled ? .semibold : .regular))
                    .foregroundStyle(isInstalled ? .white : .white.opacity(0.32))
                    .contentTransition(.symbolEffect(.replace))
            }

            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isInstalled ? .white : .white.opacity(0.42))
        }
        .animation(.spring(response: 0.3), value: isInstalled)
    }
}

private struct AppearanceStep: View {
    var onNext: () -> Void
    @AppStorage(DefaultsKey.panelPosition) private var panelPositionRaw = PanelPosition.menu.rawValue

    private struct Mode: Identifiable {
        let position: PanelPosition
        let title: String
        let subtitle: String
        var id: String { position.rawValue }
    }

    private let modes: [Mode] = [
        Mode(position: .menu, title: "Menu", subtitle: "A simple drop-down menu. The lightest option — no panel."),
        Mode(position: .notch, title: "Notch", subtitle: "A panel that flows out from the display notch."),
        Mode(position: .floating, title: "Floating", subtitle: "A compact panel you can drag anywhere on screen."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How should it appear?")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 16)

            Text("Choose how Mute opens when you click the\nmenu bar icon. You can change this in Settings.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(5)
                .padding(.bottom, 28)

            VStack(spacing: 8) {
                ForEach(modes) { mode in
                    modeRow(mode)
                }
            }
            .padding(.bottom, 28)

            OnboardingButton(title: "Continue", action: onNext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
    }

    private func modeRow(_ mode: Mode) -> some View {
        let isSelected = panelPositionRaw == mode.position.rawValue
        return Button {
            withAnimation(.spring(response: 0.3)) { panelPositionRaw = mode.position.rawValue }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.muteBlue : .white.opacity(0.3))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(mode.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.42))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.white.opacity(isSelected ? 0.08 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.muteBlue.opacity(0.6) : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct FinishStep: View {
    var onComplete: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("You're all set.")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 18)

            Text("Mute lives in your menu bar.\nIt works silently — you'll forget it's there.")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .lineSpacing(5)
                .padding(.bottom, 36)

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Launch at login")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                    Text("Recommended — starts automatically when you log in")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.32))
                }
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(.white.opacity(0.85))
                    .labelsHidden()
                    .fixedSize()
            }
            .frame(maxWidth: 400)
            .padding(.bottom, 44)

            OnboardingButton(title: "Start using Mute") {
                if launchAtLogin != (SMAppService.mainApp.status == .enabled) {
                    do {
                        if launchAtLogin {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        NSLog("Mute: launch at login \(launchAtLogin ? "register" : "unregister") failed during onboarding: \(error)")
                    }
                }
                UserDefaults.standard.set(true, forKey: DefaultsKey.onboardingCompleted)
                onComplete()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
}

private struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 220, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(isHovered ? 0.88 : 1.0))
                )
                .scaleEffect(isHovered ? 0.975 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
