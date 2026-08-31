import AppKit
import ServiceManagement
import IOKit.pwr_mgt

/// Reliable, no-entitlement system switches surfaced by the Quick Toggles widget.
///
/// Deliberately conservative: only toggles that work without private APIs or a
/// sandbox exception are included. Night Shift / True Tone / AirDrop / Bluetooth
/// all need private frameworks or extra tooling and are left out.
@MainActor
final class SystemToggles: ObservableObject {

    @Published private(set) var isDarkMode = false
    @Published private(set) var keepAwake = false
    @Published private(set) var launchAtLogin = false

    private var sleepAssertion: IOPMAssertionID = 0

    init() {
        refresh()
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(refresh),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }

    @objc func refresh() {
        isDarkMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Dark Mode

    func toggleDarkMode() {
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        runOsascript(script)
        // The distributed notification will refresh us, but nudge immediately too.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    // MARK: - Keep Awake (prevent idle sleep)

    func toggleKeepAwake() {
        if keepAwake {
            IOPMAssertionRelease(sleepAssertion)
            sleepAssertion = 0
            keepAwake = false
        } else {
            let ok = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "MacNotch — Keep Awake" as CFString,
                &sleepAssertion)
            keepAwake = (ok == kIOReturnSuccess)
        }
    }

    // MARK: - Launch at Login

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("MacNotch: launch-at-login toggle failed: \(error)")
        }
        refresh()
    }

    // MARK: -

    private func runOsascript(_ source: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        try? process.run()
    }
}
