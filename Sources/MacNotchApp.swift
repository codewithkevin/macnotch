import SwiftUI
import AppKit

@main
struct MacNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No windows/scenes — the app lives entirely in a floating NSPanel
        // managed by AppDelegate. Settings gives us a menu-less agent app.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        controller = NotchWindowController()
        controller?.show()

        // A tiny status-bar item so the app is quittable without Activity Monitor.
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.topthird.inset.filled",
                                     accessibilityDescription: "MacNotch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Reposition", action: #selector(reposition), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit MacNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func reposition() { controller?.reposition() }
    @objc private func screenChanged() { controller?.reposition() }
}
