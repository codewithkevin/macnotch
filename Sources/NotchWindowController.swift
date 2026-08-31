import AppKit
import SwiftUI
import Combine

/// Owns the borderless floating panel anchored under the notch.
///
/// The panel window is a **fixed** size (the largest state it can reach) and
/// never resizes. Resizing the window while the cursor is being tracked makes
/// the tracking-area boundary sweep past the cursor and the panel flickers
/// open/closed. All visible size changes happen inside SwiftUI instead.
///
/// `NotchInteractionView` owns hover detection: one stable tracking area over
/// the whole window, and a geometric test against the *currently visible*
/// region so hover only counts over what the user can actually see.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var interaction: NotchInteractionView?
    private let viewModel = NotchViewModel()
    private let nowPlaying = NowPlayingController()
    private let battery = BatteryMonitor()
    private var cancellables = Set<AnyCancellable>()

    func show() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        nowPlaying.start()
        battery.start()

        let panel = NotchPanel(contentRect: metrics.windowFrame())

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

        viewModel.onExpandedChange = { [weak interaction] expanded in
            interaction?.isExpanded = expanded
        }
        nowPlaying.$track
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak interaction] active in interaction?.mediaActive = active }
            .store(in: &cancellables)
    }

    func reposition() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        interaction?.metrics = metrics
        panel?.setFrame(metrics.windowFrame(), display: true, animate: false)
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
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Transparent layer that decides which mouse events belong to the notch.
///
/// One tracking area over the whole (fixed) window; every enter/move/exit is
/// funnelled through a geometric test against the currently visible region,
/// with a dwell before opening and a debounce before closing. Because the
/// window never resizes, that region only *grows* on open (cursor stays inside)
/// and *shrinks* on close (cursor has already left) — so it can't oscillate.
final class NotchInteractionView: NSView {
    var metrics: NotchMetrics? { didSet { needsDisplay = true } }
    var isExpanded = false { didSet { if isExpanded != oldValue { evaluate(at: lastPoint) } } }
    var mediaActive = false
    var onHoverChange: ((Bool) -> Void)?
    var onScroll: ((CGFloat) -> Void)?

    private var tracking: NSTrackingArea?
    private var inside = false
    private var lastPoint: NSPoint = .zero
    private var enterWork: DispatchWorkItem?
    private var exitWork: DispatchWorkItem?
    private var accumulatedScroll: CGFloat = 0
    private let scrollThreshold: CGFloat = 12
    private let openDelay: TimeInterval = 0.18
    private let closeDelay: TimeInterval = 0.16

    override var isFlipped: Bool { true }

    /// The visible region, in flipped (top-left) coords. Collapsed: the notch
    /// pill (widened by the media chins). Expanded: the whole panel, plus a
    /// generous margin so small cursor drift near the edge doesn't close it.
    private var visibleRegion: NSRect {
        guard let metrics else { return bounds }
        if isExpanded {
            return bounds.insetBy(dx: -8, dy: -8)
        }
        let size = metrics.collapsedSize(mediaActive: mediaActive)
        return NSRect(x: ((bounds.width - size.width) / 2).rounded(),
                      y: 0,
                      width: size.width.rounded(),
                      height: size.height.rounded())
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        // Stable: always the full bounds. The window never resizes, so this is
        // added exactly once per screen configuration.
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    private func point(from event: NSEvent) -> NSPoint {
        convert(event.locationInWindow, from: nil)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return visibleRegion.contains(local) ? super.hitTest(point) : nil
    }

    override func mouseEntered(with event: NSEvent) { evaluate(at: point(from: event)) }
    override func mouseMoved(with event: NSEvent) { evaluate(at: point(from: event)) }
    override func mouseExited(with event: NSEvent) {
        lastPoint = CGPoint(x: -10_000, y: -10_000)
        requestClose()
    }

    private func evaluate(at p: NSPoint) {
        lastPoint = p
        if visibleRegion.contains(p) { requestOpen() } else { requestClose() }
    }

    private func requestOpen() {
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

    private func requestClose() {
        enterWork?.cancel(); enterWork = nil
        guard inside, exitWork == nil else { return }
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
        guard visibleRegion.contains(point(from: event)) else {
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
