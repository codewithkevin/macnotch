import AppKit
import SwiftUI

/// Owns the borderless floating panel anchored under the notch.
@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private let viewModel = NotchViewModel()
    private let nowPlaying = NowPlayingController()
    private let battery = BatteryMonitor()

    func show() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        nowPlaying.start()
        battery.start()

        let panel = NotchPanel(contentRect: metrics.windowFrame())
        let host = NSHostingView(rootView: NotchView(viewModel: viewModel,
                                                     nowPlaying: nowPlaying,
                                                     battery: battery))
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func reposition() {
        let metrics = NotchMetrics.current()
        viewModel.metrics = metrics
        panel?.setFrame(metrics.windowFrame(), display: true, animate: true)
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
