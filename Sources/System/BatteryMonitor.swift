import Foundation
import IOKit.ps
import Combine

/// Publishes the internal battery state via IOKit power sources.
@MainActor
final class BatteryMonitor: ObservableObject {

    struct State: Equatable {
        var percent: Int          // 0...100
        var isCharging: Bool
        var isPluggedIn: Bool
        var isCharged: Bool
        var minutesRemaining: Int?   // to empty (discharging) or to full (charging)
    }

    @Published private(set) var state: State?

    /// True right after a charger is connected — drives a short charge animation.
    @Published private(set) var justPluggedIn = false

    private var runLoopSource: CFRunLoopSource?
    private var plugInResetWork: DispatchWorkItem?

    func start() {
        refresh()

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(ctx).takeUnretainedValue()
            Task { @MainActor in monitor.refresh() }
        }, context)?.takeRetainedValue() else { return }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }
        runLoopSource = nil
    }

    private func refresh() {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            state = nil
            return
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: Any] else { continue }
            guard (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let sourceState = info[kIOPSPowerSourceStateKey] as? String
            let pluggedIn = sourceState == kIOPSACPowerValue
            let charged = info[kIOPSIsChargedKey] as? Bool ?? false

            let timeKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            let rawMinutes = info[timeKey] as? Int ?? -1
            let minutes = rawMinutes > 0 ? rawMinutes : nil

            let newState = State(percent: percent,
                                 isCharging: charging,
                                 isPluggedIn: pluggedIn,
                                 isCharged: charged,
                                 minutesRemaining: minutes)

            if let old = state, !old.isPluggedIn, newState.isPluggedIn {
                triggerPlugInAnimation()
            }
            state = newState
            return
        }

        state = nil   // No internal battery (desktop Mac).
    }

    private func triggerPlugInAnimation() {
        justPluggedIn = true
        plugInResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.justPluggedIn = false }
        plugInResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }
}

extension BatteryMonitor.State {
    /// SF Symbol name that mirrors the current level / charging state.
    var symbolName: String {
        if isCharging || (isPluggedIn && !isCharged) { return "battery.100percent.bolt" }
        switch percent {
        case ..<13:  return "battery.0percent"
        case ..<38:  return "battery.25percent"
        case ..<63:  return "battery.50percent"
        case ..<88:  return "battery.75percent"
        default:     return "battery.100percent"
        }
    }

    var timeRemainingString: String? {
        guard let m = minutesRemaining else { return nil }
        let h = m / 60, mm = m % 60
        return h > 0 ? "\(h)h \(mm)m" : "\(mm)m"
    }
}
