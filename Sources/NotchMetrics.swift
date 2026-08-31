import AppKit

/// Geometry describing the physical notch (or a simulated one on Macs without a notch).
struct NotchMetrics {
    /// Width of the hardware notch in points.
    var notchWidth: CGFloat
    /// Height of the hardware notch / menu-bar inset in points.
    var notchHeight: CGFloat
    /// The screen the notch belongs to.
    var screen: NSScreen
    /// Whether this Mac actually has a notch.
    var isRealNotch: Bool

    /// Expanded panel size when the user hovers.
    var expandedSize: CGSize { CGSize(width: 780, height: 210) }

    static func current() -> NotchMetrics {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens[0]

        let topInset = screen.safeAreaInsets.top

        if topInset > 0, let leftArea = screen.auxiliaryTopLeftArea, let rightArea = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - leftArea.width - rightArea.width
            return NotchMetrics(notchWidth: width,
                                notchHeight: topInset,
                                screen: screen,
                                isRealNotch: true)
        }

        // Simulated notch for non-notch Macs.
        return NotchMetrics(notchWidth: 200,
                            notchHeight: 32,
                            screen: screen,
                            isRealNotch: false)
    }

    var collapsedSize: CGSize {
        CGSize(width: max(notchWidth, 180), height: max(notchHeight, 28))
    }

    /// Window frame (screen coords) centred on the notch, pinned to the top edge.
    /// The window is only as large as it needs to be so it doesn't swallow clicks
    /// or scroll gestures elsewhere along the top of the screen.
    func windowFrame(expanded: Bool) -> NSRect {
        let f = screen.frame
        let size = expanded ? expandedSize : collapsedSize
        let x = f.midX - size.width / 2
        let y = f.maxY - size.height
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }
}
