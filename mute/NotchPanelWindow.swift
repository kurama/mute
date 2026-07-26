import AppKit
import SwiftUI

final class NotchPanelWindow: NSPanel {
    private var outsideClickMonitor: Any?

    init(viewModel: NotchPanelViewModel, onToggle: @escaping () -> Void, onSnooze: @escaping (TimeInterval) -> Void, onTriggerModeChange: @escaping (TriggerMode) -> Void, onLaunchAtLoginChange: @escaping (Bool) -> Bool) {
        let notchH = NSScreen.main?.safeAreaInsets.top ?? 0
        let totalH: CGFloat = 88 + (notchH > 0 ? notchH : 0)

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovable = false

        let view = NotchPanelView(
            viewModel: viewModel,
            notchHeight: notchH,
            onToggle: { [weak self] in onToggle(); self?.hide() },
            onSnooze: { duration in onSnooze(duration) },
            onTriggerModeChange: onTriggerModeChange,
            onLaunchAtLoginChange: onLaunchAtLoginChange
        )
        .environment(\.colorScheme, .dark)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 644, height: totalH)
        contentView = host
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard let screen = NSScreen.main else { return }
        position(on: screen)
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.18
            $0.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.hide() }
    }

    func hide() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
        NSAnimationContext.runAnimationGroup({
            $0.duration = 0.14
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    private func position(on screen: NSScreen) {
        let w: CGFloat = 644
        let notchH = screen.safeAreaInsets.top
        let h: CGFloat = 88 + (notchH > 0 ? notchH : 0)
        let x = screen.frame.midX - w / 2
        let y = notchH > 0
            ? screen.frame.maxY - h      // top edge flush with top of screen, merges into notch
            : screen.visibleFrame.maxY - h
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
    }
}
