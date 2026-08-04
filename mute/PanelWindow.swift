import AppKit
import SwiftUI

final class PanelWindow: NSPanel, NSWindowDelegate {
    private let viewModel: PanelViewModel
    private var outsideClickMonitor: Any?
    /// The display mode the current window frame/chrome was laid out for, so a mode
    /// change while the panel is open can be detected and re-applied.
    private var appliedPosition: PanelPosition?
    /// Screen frame of the status bar icon, used to place the floating panel on first open.
    var statusItemFrameProvider: (() -> NSRect?)?

    init(viewModel: PanelViewModel, onToggle: @escaping () -> Void, onFocus: @escaping (TimeInterval) -> Void, onOpenSettings: @escaping () -> Void) {
        self.viewModel = viewModel
        let notchH = NSScreen.main?.effectiveNotchHeight ?? PanelPosition.fallbackNotchHeight
        let totalH = PanelPosition.notchBodyHeight + notchH

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

        viewModel.notchHeight = notchH
        let view = PanelView(
            viewModel: viewModel,
            onToggle: { [weak self] in onToggle(); self?.hide() },
            onFocus: { duration in onFocus(duration) },
            onOpenSettings: { [weak self] in onOpenSettings(); self?.hide() }
        )
        .environment(\.colorScheme, .dark)

        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: PanelPosition.notchWidth, height: totalH)
        contentView = host
        delegate = self

        // Re-lay-out live when the display mode is switched in Settings while the
        // panel is open, instead of leaving it stuck in the previous mode's frame.
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDefaultsChange),
            name: UserDefaults.didChangeNotification, object: nil
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        // In "menu" mode there is no panel — the status bar icon shows a menu instead.
        guard applyLayout() else { return }
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

    /// Size, position and window chrome for the current display mode. Returns false
    /// (no-op) in "menu" mode or when no screen is available. Safe to call again
    /// while the panel is visible, e.g. when the mode is switched in Settings.
    @discardableResult
    private func applyLayout() -> Bool {
        let position = PanelPosition.current
        guard position != .menu, let screen = targetScreen() else { return false }
        appliedPosition = position
        // Only the free-floating panel is draggable; the notch panel is pinned flush
        // against the top edge.
        isMovable = position == .floating
        isMovableByWindowBackground = position == .floating
        // Only the free-floating panel casts a shadow. The shadow also keeps the
        // borderless window fully composited while dragging (without it, parts stop
        // redrawing mid-drag).
        hasShadow = position == .floating
        switch position {
        case .notch: positionAtNotch(on: screen)
        case .floating: positionFloating(on: screen)
        case .menu: return false
        }
        applyRoundedClip(position == .floating)
        return true
    }

    // Round + border the floating panel at the content layer (a crisp compositor
    // mask) rather than in SwiftUI. Combined with the window shadow this gives the
    // rounded edge a hard boundary, so the shadow sits cleanly outside instead of
    // bleeding through the material's soft edge as a rim. The notch layout keeps its
    // own concave SwiftUI clip, so the layer mask is disabled there.
    private func applyRoundedClip(_ enabled: Bool) {
        contentView?.wantsLayer = true
        guard let layer = contentView?.layer else { return }
        layer.cornerCurve = .continuous
        layer.cornerRadius = enabled ? 18 : 0
        layer.masksToBounds = enabled
        layer.borderWidth = enabled ? 1 : 0
        layer.borderColor = enabled ? NSColor.white.withAlphaComponent(0.12).cgColor : nil
    }

    // A mode switch in Settings only re-renders the SwiftUI content; the AppKit
    // window keeps the old frame/chrome until we re-lay it out here.
    @objc private func handleDefaultsChange() {
        guard isVisible else { return }
        let position = PanelPosition.current
        guard position != appliedPosition else { return }
        appliedPosition = position
        if position == .menu { hide(); return }
        // Defer so SwiftUI has re-rendered the new layout before we read its fitting size.
        DispatchQueue.main.async { [weak self] in
            self?.applyLayout()
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

    /// The screen the panel should open on: the one holding the status bar icon, so
    /// it appears on the display the user clicked (notch anchoring included). Falls
    /// back to the main screen — and finally any screen — if the icon can't be found.
    private func targetScreen() -> NSScreen? {
        if let frame = statusItemFrameProvider?() {
            let anchor = CGPoint(x: frame.midX, y: frame.midY)
            if let match = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) {
                return match
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func positionAtNotch(on screen: NSScreen) {
        let w = PanelPosition.notchWidth
        // Follow the notch of the screen we're actually landing on, which may differ
        // from the one the window was built on.
        viewModel.notchHeight = screen.effectiveNotchHeight
        let h = PanelPosition.notchBodyHeight + viewModel.notchHeight
        contentView?.setFrameSize(NSSize(width: w, height: h))
        let x = screen.frame.midX - w / 2
        // Always hang from the very top edge; on notch-less displays this simulates
        // a notch instead of leaving the panel floating below the menu bar.
        let y = screen.frame.maxY - h
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: false)
    }

    private func positionFloating(on screen: NSScreen) {
        // The compact layout sizes itself to its content (at least floatingWidth),
        // so read both dimensions from SwiftUI rather than pinning the width.
        let fitting = contentView?.fittingSize ?? .zero
        let w = max(PanelPosition.floatingWidth, fitting.width)
        let h = max(fitting.height, 120)
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
