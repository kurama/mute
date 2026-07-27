import AppKit
import SwiftUI

final class NotchPanelWindow: NSPanel, NSWindowDelegate {
    private var outsideClickMonitor: Any?
    /// Screen frame of the status bar icon, used to place the floating panel on first open.
    var statusItemFrameProvider: (() -> NSRect?)?

    init(viewModel: NotchPanelViewModel, onToggle: @escaping () -> Void, onFocus: @escaping (TimeInterval) -> Void, onOpenSettings: @escaping () -> Void) {
        let notchH = NSScreen.main?.effectiveNotchHeight ?? PanelPosition.fallbackNotchHeight
        let totalH: CGFloat = 88 + notchH

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
            onFocus: { duration in onFocus(duration) },
            onOpenSettings: { [weak self] in onOpenSettings(); self?.hide() }
        )
        .environment(\.colorScheme, .dark)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 644, height: totalH)
        contentView = host
        delegate = self
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard let screen = NSScreen.main else { return }
        let position = PanelPosition.current
        // Only the free-floating panel is draggable and casts a shadow;
        // the notch panel is pinned flush against the top edge.
        isMovable = position == .floating
        isMovableByWindowBackground = position == .floating
        hasShadow = position == .floating
        switch position {
        case .notch: positionAtNotch(on: screen)
        case .floating: positionFloating(on: screen)
        }
        alphaValue = 0
        orderFront(nil)
        NSAnimationContext.runAnimationGroup {
            $0.duration = 0.18
            $0.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
        if UserDefaults.standard.bool(forKey: DefaultsKey.panelDismissOnOutsideClick) {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in self?.hide() }
        }
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

    private func positionAtNotch(on screen: NSScreen) {
        let w: CGFloat = 644
        let h = 88 + screen.effectiveNotchHeight
        contentView?.setFrameSize(NSSize(width: w, height: h))
        let x = screen.frame.midX - w / 2
        // Always hang from the very top edge; on notch-less displays this simulates
        // a notch instead of leaving the panel floating below the menu bar.
        let y = screen.frame.maxY - h
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
    }

    private func positionFloating(on screen: NSScreen) {
        let w = PanelPosition.floatingWidth
        // The compact layout has an intrinsic height; let SwiftUI size it.
        let h = max(contentView?.fittingSize.height ?? 0, 120)
        contentView?.setFrameSize(NSSize(width: w, height: h))

        let margin: CGFloat = 8
        var origin: NSPoint
        if let saved = savedFloatingOrigin() {
            origin = saved
        } else {
            // First time: center under the icon (top-right), just below the menu bar.
            let anchor = statusItemFrameProvider?()
            let x = (anchor?.midX ?? screen.visibleFrame.maxX) - w / 2
            let top = anchor?.minY ?? screen.visibleFrame.maxY
            origin = NSPoint(x: x, y: top - margin - h)
        }
        // Keep the panel fully on screen wherever it was anchored or dragged.
        origin.x = min(max(screen.frame.minX + margin, origin.x), screen.frame.maxX - w - margin)
        origin.y = min(max(screen.frame.minY + margin, origin.y), screen.frame.maxY - h - margin)
        setFrame(NSRect(origin: origin, size: NSSize(width: w, height: h)), display: false)
    }

    private func savedFloatingOrigin() -> NSPoint? {
        guard let values = UserDefaults.standard.array(forKey: DefaultsKey.panelFloatingOrigin) as? [Double],
              values.count == 2 else { return nil }
        return NSPoint(x: values[0], y: values[1])
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        // Remember where the user parked the panel, but ignore the programmatic
        // setFrame during show() (which happens before the window is on screen).
        guard isVisible, PanelPosition.current == .floating else { return }
        UserDefaults.standard.set([Double(frame.origin.x), Double(frame.origin.y)],
                                  forKey: DefaultsKey.panelFloatingOrigin)
    }
}

private extension NSScreen {
    /// The physical notch inset, or a fallback height on notch-less displays.
    var effectiveNotchHeight: CGFloat {
        let inset = safeAreaInsets.top
        return inset > 0 ? inset : PanelPosition.fallbackNotchHeight
    }
}
