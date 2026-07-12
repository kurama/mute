import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @State private var step = 0
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.06)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    if step == 0 {
                        WelcomeStep(onNext: advance)
                            .transition(slideTransition)
                    } else if step == 1 {
                        ShortcutsStep(onNext: advance)
                            .transition(slideTransition)
                    } else {
                        FinishStep(onComplete: onComplete)
                            .transition(slideTransition)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
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

// MARK: - Welcome

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

// MARK: - Shortcuts

private struct ShortcutsStep: View {
    var onNext: () -> Void
    @State private var muteOnInstalled = false
    @State private var muteOffInstalled = false
    @State private var isInstalling = false

    private var allInstalled: Bool { muteOnInstalled && muteOffInstalled }

    private static var alreadyInstalled: Bool {
        UserDefaults.standard.bool(forKey: "shortcutsInstalled")
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

                Button("Skip for now") { onNext() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 16)
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
                guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else { continue }
                NSWorkspace.shared.open(url)
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.spring(response: 0.3)) {
                    if name == "Mute On" { muteOnInstalled = true }
                    else { muteOffInstalled = true }
                }
            }
            isInstalling = false
            UserDefaults.standard.set(true, forKey: "shortcutsInstalled")
        }
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

// MARK: - Finish

private struct FinishStep: View {
    var onComplete: () -> Void
    @State private var launchAtLogin = true

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
                if launchAtLogin {
                    try? SMAppService.mainApp.register()
                }
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                onComplete()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 60)
    }
}

// MARK: - Shared button

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
