import AppKit
import SwiftUI
import Combine

/// Owns the borderless floating panel anchored under the notch.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private let viewModel = NotchViewModel()
    private let nowPlaying = NowPlayingController()
    private let battery = BatteryMonitor()
    private var cancellables = Set<AnyCancellable>()

    func show() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        nowPlaying.start()
        battery.start()

        let panel = NotchPanel(contentRect: metrics.windowFrame(expanded: false))
        let host = ScrollHostingView(rootView: NotchView(viewModel: viewModel,
                                                         nowPlaying: nowPlaying,
                                                         battery: battery))
        host.onScroll = { [weak viewModel] deltaY in
            // Two-finger swipe DOWN (deltaY < 0) opens; swipe UP closes.
            guard let viewModel else { return }
            if deltaY < 0, !viewModel.isExpanded { viewModel.expandFromGesture() }
            else if deltaY > 0, viewModel.isExpanded { viewModel.setExpanded(false) }
        }
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel

        // Grow / shrink the window to match the panel state so the transparent
        // window never covers more of the screen than the visible panel.
        viewModel.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in self?.resizePanel(expanded: expanded) }
            .store(in: &cancellables)
    }

    private func resizePanel(expanded: Bool) {
        let frame = viewModel.metrics.windowFrame(expanded: expanded)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().setFrame(frame, display: true)
        }
    }

    func reposition() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        panel?.setFrame(metrics.windowFrame(expanded: viewModel.isExpanded), display: true, animate: true)
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

/// Hosting view that forwards two-finger scroll gestures so the notch can be
/// opened/closed by swiping, not just by hovering.
final class ScrollHostingView<Content: View>: NSHostingView<Content> {
    var onScroll: ((CGFloat) -> Void)?

    /// Accumulated scroll distance within the current gesture; reset between gestures.
    private var accumulated: CGFloat = 0
    private let threshold: CGFloat = 12

    required init(rootView: Content) { super.init(rootView: rootView) }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
    @available(*, unavailable)
    @MainActor @preconcurrency required dynamic init(rootView: Content, sizingOptions: NSHostingSizingOptions) {
        fatalError()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.phase == .began || event.momentumPhase == .began { accumulated = 0 }
        accumulated += event.scrollingDeltaY
        if abs(accumulated) >= threshold {
            onScroll?(accumulated)
            accumulated = 0
        }
        if event.phase == .ended || event.momentumPhase == .ended { accumulated = 0 }
    }
}
