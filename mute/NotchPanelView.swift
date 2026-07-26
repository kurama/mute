import SwiftUI
import ServiceManagement

struct NotchPanelView: View {
    var viewModel: NotchPanelViewModel
    var notchHeight: CGFloat = 0
    var onToggle: () -> Void
    var onFocus: (TimeInterval) -> Void
    var onTriggerModeChange: (TriggerMode) -> Void
    var onLaunchAtLoginChange: (Bool) -> Bool

    @State private var showSettings = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    // The concave top / convex bottom corners inset the panel body by `cornerRadius`,
    // so content padding must compensate to keep an even margin on every side.
    private let cornerRadius: CGFloat = 22
    private let contentMargin: CGFloat = 24
    private var edgePadding: CGFloat { cornerRadius + contentMargin }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                tabButtons
                Spacer()
                if viewModel.triggerMode != .cameraOnly { micWingView }
                if viewModel.triggerMode != .micOnly { cameraWingView }
            }
            .padding(.horizontal, edgePadding)
            .frame(height: notchHeight)

            if showSettings {
                settingsView
                    .transition(.opacity)
            } else {
                mainView
                    .transition(.opacity)
            }
        }
        .frame(width: 644, height: 88 + notchHeight)
        .background(.black)
        .clipShape(NotchPanelShape(topCornerRadius: cornerRadius, bottomCornerRadius: cornerRadius))
        .animation(.easeInOut(duration: 0.18), value: showSettings)
    }

    private var tabButtons: some View {
        HStack(spacing: 6) {
            Button { showSettings = false } label: {
                HStack(spacing: 5) {
                    Image(systemName: "house")
                        .font(.system(size: 11, weight: .medium))
                    Text("Panel")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(showSettings ? .white.opacity(0.35) : .white.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(showSettings ? Color.clear : Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11, weight: .medium))
                    Text("Settings")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(showSettings ? .white.opacity(0.85) : .white.opacity(0.35))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(showSettings ? Color.white.opacity(0.08) : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .animation(.easeInOut(duration: 0.15), value: showSettings)
    }

    // MARK: - Main view

    private var mainView: some View {
        HStack(spacing: 0) {
            dndStatusSection
            Spacer()
            buttonsSection
        }
        .padding(.horizontal, edgePadding)
        .frame(height: 88)
    }

    private var micWingView: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.isMicActive ? "mic.fill" : "mic")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.isMicActive ? .white : .white.opacity(0.35))
            Text("Mic")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.isMicActive ? .white : .white.opacity(0.35))
            if viewModel.isMicActive {
                WingWaveformView()
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(viewModel.isMicActive ? Color.muteBlue : Color.clear)
        .clipShape(Capsule())
        .animation(.spring(duration: 0.25), value: viewModel.isMicActive)
    }

    private var cameraWingView: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.isCameraActive ? "camera.fill" : "camera")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.isCameraActive ? .white : .white.opacity(0.35))
            Text("Cam")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(viewModel.isCameraActive ? .white : .white.opacity(0.35))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(viewModel.isCameraActive ? Color.muteBlue : Color.clear)
        .clipShape(Capsule())
        .animation(.spring(duration: 0.25), value: viewModel.isCameraActive)
    }

    private var dndStatusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Do Not Disturb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            if viewModel.isActive || viewModel.isFocusing {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.muteBlue)
                            .frame(width: 5, height: 5)
                        Text(viewModel.isFocusing ? "Focus · \(viewModel.focusRemaining)" : "DND · \(viewModel.dndDuration)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.muteBlue)
                    }
                }
            } else {
                Text("Inactive")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var buttonsSection: some View {
        HStack(spacing: 8) {
            if viewModel.isFocusing {
                PillButton(title: "End Focus", style: .positive) { onToggle() }
            } else if viewModel.isMonitoringEnabled {
                if viewModel.isActive {
                    PillButton(title: "Disable", style: .neutral) { onToggle() }
                }
                focusMenu
            } else {
                PillButton(title: "Enable", style: .neutral) { onToggle() }
            }
        }
    }

    private var focusMenu: some View {
        Menu {
            Button("5 min")   { onFocus(5 * 60) }
            Button("15 min")  { onFocus(15 * 60) }
            Button("30 min")  { onFocus(30 * 60) }
            Button("1 hour")  { onFocus(3600) }
        } label: {
            Text("Focus")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Settings view

    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trigger on")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                HStack(spacing: 6) {
                    triggerPill("Mic & Cam", .micAndCamera)
                    triggerPill("Mic", .micOnly)
                    triggerPill("Camera", .cameraOnly)
                }
            }
            HStack {
                Text("Launch at login")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(Color.muteBlue)
                    .scaleEffect(0.75, anchor: .trailing)
                    .onChange(of: launchAtLogin) { _, newValue in
                        // Ignore programmatic syncs (onAppear / revert): only act on a real user change.
                        guard newValue != (SMAppService.mainApp.status == .enabled) else { return }
                        let actual = onLaunchAtLoginChange(newValue)
                        // Reflect reality: if register/unregister failed, snap the toggle back.
                        if actual != newValue { launchAtLogin = actual }
                    }
            }
        }
        .padding(.horizontal, edgePadding)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        // Re-read the real status every time Settings is opened, not just at launch.
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func triggerPill(_ title: String, _ mode: TriggerMode) -> some View {
        Button(title) { onTriggerModeChange(mode) }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(viewModel.triggerMode == mode ? .white : .white.opacity(0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(viewModel.triggerMode == mode ? Color.muteBlue : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .buttonStyle(.plain)
    }
}

/// Panel outline with concave (inverted) fillets at the top corners so the panel
/// appears to flow out of the menu bar, and convex rounded corners at the bottom.
struct NotchPanelShape: Shape {
    var topCornerRadius: CGFloat = 14
    var bottomCornerRadius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let tr = min(topCornerRadius, rect.width / 2, rect.height)
        let br = min(bottomCornerRadius, (rect.width - 2 * topCornerRadius) / 2, rect.height)
        var p = Path()
        // Top edge (full width, flush with the menu bar).
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        // Top-right concave fillet.
        p.addQuadCurve(to: CGPoint(x: rect.width - tr, y: tr),
                       control: CGPoint(x: rect.width - tr, y: 0))
        p.addLine(to: CGPoint(x: rect.width - tr, y: rect.height - br))
        // Bottom-right convex corner.
        p.addQuadCurve(to: CGPoint(x: rect.width - tr - br, y: rect.height),
                       control: CGPoint(x: rect.width - tr, y: rect.height))
        p.addLine(to: CGPoint(x: tr + br, y: rect.height))
        // Bottom-left convex corner.
        p.addQuadCurve(to: CGPoint(x: tr, y: rect.height - br),
                       control: CGPoint(x: tr, y: rect.height))
        p.addLine(to: CGPoint(x: tr, y: tr))
        // Top-left concave fillet.
        p.addQuadCurve(to: CGPoint(x: 0, y: 0),
                       control: CGPoint(x: tr, y: 0))
        p.closeSubpath()
        return p
    }
}

enum PillButtonStyle { case neutral, positive }

struct PillButton: View {
    let title: String
    let style: PillButtonStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(style == .positive ? Color.muteBlue : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct WaveformView: View {
    @State private var animating = false
    private let heights: [CGFloat] = [3, 8, 12, 8, 3]

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.muteBlue)
                    .frame(width: 2.5, height: animating ? heights[i] : heights[i] * 0.35)
                    .animation(
                        .easeInOut(duration: 0.35 + Double(i) * 0.07)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.09),
                        value: animating
                    )
            }
        }
        .frame(height: 14)
        .onAppear { animating = true }
    }
}

struct WingWaveformView: View {
    @State private var animating = false
    private let heights: [CGFloat] = [3, 6, 9, 6, 3]

    var body: some View {
        HStack(alignment: .center, spacing: 1.5) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white)
                    .frame(width: 2, height: animating ? heights[i] : heights[i] * 0.35)
                    .animation(
                        .easeInOut(duration: 0.35 + Double(i) * 0.07)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.09),
                        value: animating
                    )
            }
        }
        .frame(height: 12)
        .onAppear { animating = true }
    }
}

extension Color {
    static let muteBlue = Color(red: 42/255, green: 90/255, blue: 210/255)
}
