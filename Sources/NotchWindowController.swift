import AppKit
import SwiftUI

/// Owns the borderless floating panel anchored under the notch.
///
/// The panel window is a *fixed* size (the expanded bounds) and never resizes —
/// resizing it while tracking the cursor causes hover flicker. Instead a single
/// AppKit view (`NotchInteractionView`) owns hover detection and hit-testing:
/// it only claims mouse events inside the currently-visible panel region and
/// lets everything else fall through to the apps below.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var interaction: NotchInteractionView?
    private let viewModel = NotchViewModel()
    private let nowPlaying = NowPlayingController()
    private let battery = BatteryMonitor()

    func show() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        nowPlaying.start()
        battery.start()

        let panel = NotchPanel(contentRect: metrics.windowFrame(expanded: true))

        let interaction = NotchInteractionView()
        interaction.frame = panel.contentLayoutRect
        interaction.autoresizingMask = [.width, .height]
        interaction.metrics = metrics
        interaction.onHoverChange = { [weak viewModel] hovering in
            guard let viewModel else { return }
            if hovering { viewModel.setExpanded(true) }
            else { viewModel.setExpanded(false) }
        }
        interaction.onScroll = { [weak viewModel] deltaY in
            guard let viewModel else { return }
            if deltaY < 0 { viewModel.expandFromGesture() }
            else if deltaY > 0 { viewModel.setExpanded(false) }
        }

        let host = NSHostingView(rootView: NotchView(viewModel: viewModel,
                                                     nowPlaying: nowPlaying,
                                                     battery: battery))
        host.frame = interaction.bounds
        host.autoresizingMask = [.width, .height]
        host.translatesAutoresizingMaskIntoConstraints = true
        interaction.addSubview(host)

        panel.contentView = interaction
        panel.orderFrontRegardless()
        self.panel = panel
        self.interaction = interaction

        // Keep the interaction view's notion of "expanded" in sync so its
        // tracking rect matches what the user actually sees.
        viewModel.onExpandedChange = { [weak interaction] expanded in
            interaction?.isExpanded = expanded
        }
    }

    func reposition() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        interaction?.metrics = metrics
        panel?.setFrame(metrics.windowFrame(expanded: true), display: true, animate: false)
    }
}

/// A non-activating, always-on-top, transparent panel that floats above
/// full-screen apps and does not appear in Mission Control or the Dock.
final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Transparent AppKit layer that decides which mouse events belong to the notch.
///
/// * `hitTest` returns `nil` outside the visible panel rect, so clicks and
///   scrolls elsewhere along the top of the screen pass through untouched.
/// * A tracking area covering the visible rect drives `onHoverChange`, with a
///   short exit debounce so brushing the edge doesn't strobe the panel.
final class NotchInteractionView: NSView {
    var metrics: NotchMetrics? { didSet { refreshTracking() } }
    var isExpanded = false { didSet { if isExpanded != oldValue { refreshTracking() } } }
    var onHoverChange: ((Bool) -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    private var tracking: NSTrackingArea?
    private var inside = false
    private var enterWork: DispatchWorkItem?
    private var exitWork: DispatchWorkItem?
    private var accumulatedScroll: CGFloat = 0
    private let scrollThreshold: CGFloat = 12
    /// The cursor must dwell this long over the notch before the panel opens,
    /// so a quick pass across the top of the screen doesn't trigger it.
    private let openDelay: TimeInterval = 0.16
    private let closeDelay: TimeInterval = 0.14

    override var isFlipped: Bool { true }

    /// The region that should keep the panel alive, in flipped (top-left) coords.
    /// Collapsed: just the notch. Expanded: the whole (now panel-sized) window.
    private var hotRect: NSRect {
        guard let metrics, !isExpanded else { return bounds }
        let size = metrics.collapsedSize
        return NSRect(x: (bounds.width - size.width) / 2,
                      y: 0,
                      width: size.width,
                      height: size.height)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: hotRect,
                                  options: [.mouseEnteredAndExited, .activeAlways],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    func refreshTracking() { needsDisplay = true; updateTrackingAreas() }

    private func point(from event: NSEvent) -> NSPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return hotRect.contains(local) ? super.hitTest(point) : nil
    }

    override func mouseEntered(with event: NSEvent) {
        // Confirm the pointer is genuinely inside the hot rect.
        guard hotRect.contains(point(from: event)) else { return }
        scheduleEnter()
    }

    override func mouseExited(with event: NSEvent) { scheduleExit() }

    private func scheduleEnter() {
        exitWork?.cancel(); exitWork = nil
        guard !inside, enterWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.enterWork = nil
            self.inside = true
            self.onHoverChange?(true)
        }
        enterWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + openDelay, execute: work)
    }

    private func scheduleExit() {
        enterWork?.cancel(); enterWork = nil
        exitWork?.cancel()
        guard inside else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.exitWork = nil
            self.inside = false
            self.onHoverChange?(false)
        }
        exitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: work)
    }

    override func scrollWheel(with event: NSEvent) {
        guard hotRect.contains(point(from: event)) else {
            super.scrollWheel(with: event)
            return
        }
        if event.phase == .began { accumulatedScroll = 0 }
        accumulatedScroll += event.scrollingDeltaY
        if abs(accumulatedScroll) >= scrollThreshold {
            onScroll?(accumulatedScroll)
            accumulatedScroll = 0
        }
        if event.phase == .ended { accumulatedScroll = 0 }
    }
}
