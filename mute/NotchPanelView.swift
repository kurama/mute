import SwiftUI

struct NotchPanelView: View {
    var viewModel: NotchPanelViewModel
    var onToggle: () -> Void
    var onSnooze: (TimeInterval) -> Void

    var body: some View {
        HStack(spacing: 0) {
            micSection
            divider
            cameraSection
            Spacer()
            divider
            actionsSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(width: 440, height: 88)
        .background(.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 36)
            .padding(.horizontal, 14)
    }

    private var micSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.isMicActive ? "mic.fill" : "mic")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(viewModel.isMicActive ? Color.green : Color.white.opacity(0.45))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isMicActive)
                Text("Mic")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.isMicActive ? Color.primary : Color.white.opacity(0.45))
            }
            if viewModel.isMicActive {
                WaveformView()
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
            } else {
                Text("Idle")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.28))
            }
        }
        .frame(width: 72, alignment: .leading)
        .animation(.spring(duration: 0.25), value: viewModel.isMicActive)
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.isCameraActive ? "camera.fill" : "camera")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(viewModel.isCameraActive ? Color.green : Color.white.opacity(0.45))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.isCameraActive)
                Text("Camera")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(viewModel.isCameraActive ? Color.primary : Color.white.opacity(0.45))
            }
            Text(viewModel.isCameraActive ? "Active" : "Idle")
                .font(.system(size: 10))
                .foregroundStyle(viewModel.isCameraActive ? Color.green.opacity(0.75) : Color.white.opacity(0.28))
                .animation(.easeInOut(duration: 0.2), value: viewModel.isCameraActive)
        }
        .frame(width: 92, alignment: .leading)
    }

    private var actionsSection: some View {
        VStack(alignment: .trailing, spacing: 7) {
            dndLabel
            HStack(spacing: 8) {
                if viewModel.isSnoozed {
                    PillButton(title: "Snoozed", style: .positive) { onToggle() }
                } else if viewModel.isMonitoringEnabled {
                    PillButton(title: "Disable", style: .neutral) { onToggle() }
                    snoozeMenu
                } else {
                    PillButton(title: "Enable", style: .neutral) { onToggle() }
                }
            }
        }
    }

    @ViewBuilder
    private var dndLabel: some View {
        if viewModel.isActive || viewModel.isSnoozed {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                    Text(viewModel.isSnoozed ? "DND · snooze" : "DND · \(viewModel.dndDuration)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var snoozeMenu: some View {
        Menu {
            Button("5 min")   { onSnooze(5 * 60) }
            Button("15 min")  { onSnooze(15 * 60) }
            Button("30 min")  { onSnooze(30 * 60) }
            Button("1 heure") { onSnooze(3600) }
        } label: {
            Text("Snooze")
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
                .foregroundStyle(style == .positive ? Color.black : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(style == .positive ? Color.green : Color.white.opacity(0.1))
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
                    .fill(Color.green)
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
