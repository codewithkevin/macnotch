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

    /// Expanded panel size. One "page" of content is shown at a time and the
    /// user swipes horizontally between pages, so this stays compact.
    var expandedSize: CGSize { CGSize(width: 460, height: 320) }

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

    var barHeight: CGFloat { max(notchHeight, 26) }

    /// How far the black "chin" extends past each side of the physical notch when
    /// a Now Playing activity is shown — room for album art on the left and the
    /// visualizer on the right (same idea as The Boring Notch).
    var sideChinWidth: CGFloat { max(0, barHeight - 12) + 16 }

    /// Collapsed window size. Just the physical notch normally; widened on both
    /// sides when media is playing so the live activity has somewhere to draw.
    func collapsedSize(mediaActive: Bool) -> CGSize {
        let w = max(notchWidth, 120)
        return CGSize(width: mediaActive ? w + sideChinWidth * 2 : w, height: barHeight)
    }

    /// The fixed window frame (screen coords): sized to the largest state the
    /// panel can reach, centred on the notch and pinned to the top edge. The
    /// window never changes size — SwiftUI animates the visible content within.
    func windowFrame() -> NSRect {
        let f = screen.frame
        let w = max(expandedSize.width, collapsedSize(mediaActive: true).width)
        let h = expandedSize.height
        return NSRect(x: f.midX - w / 2, y: f.maxY - h, width: w, height: h)
    }
}
