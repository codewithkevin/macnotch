import Foundation
import Combine

/// A named dashboard configuration the user can switch between — manually, on a
/// schedule, or (best effort) when a macOS Focus turns on.
struct Profile: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var slots: [DashboardWidgetKind]
    /// Name of the macOS Focus that should activate this profile, if any.
    var focusName: String?
    /// Time window that should activate this profile, if any.
    var schedule: Schedule?

    struct Schedule: Codable, Equatable {
        /// 1 = Sunday … 7 = Saturday (matches `Calendar.component(.weekday)`).
        var weekdays: Set<Int>
        var startMinute: Int   // minutes from midnight
        var endMinute: Int

        func contains(_ date: Date) -> Bool {
            let cal = Calendar.current
            let wd = cal.component(.weekday, from: date)
            guard weekdays.contains(wd) else { return false }
            let m = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
            return startMinute <= endMinute
                ? (m >= startMinute && m < endMinute)
                : (m >= startMinute || m < endMinute)   // wraps past midnight
        }
    }
}

@MainActor
final class ProfileStore: ObservableObject {
    private static let profilesKey = "profiles.v1"
    private static let activeKey = "profiles.active.v1"
    /// When true, schedule / Focus rules are allowed to switch the active profile.
    private static let autoKey = "profiles.auto.v1"

    @Published var profiles: [Profile] { didSet { persist() } }
    @Published var activeID: UUID? { didSet { UserDefaults.standard.set(activeID?.uuidString, forKey: Self.activeKey) } }
    @Published var autoSwitch: Bool { didSet { UserDefaults.standard.set(autoSwitch, forKey: Self.autoKey) } }

    /// Set by whoever owns the live layout so a profile switch can apply it.
    var applyLayout: (([DashboardWidgetKind]) -> Void)?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data), !decoded.isEmpty {
            profiles = decoded
        } else {
            profiles = [
                Profile(name: "Default", slots: [.dayProgress, .weather, .quote, .shelf]),
                Profile(name: "Work", slots: [.appLauncher, .shortcuts, .dayProgress, .battery],
                        schedule: .init(weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 18 * 60)),
            ]
        }
        activeID = UserDefaults.standard.string(forKey: Self.activeKey).flatMap(UUID.init)
        autoSwitch = UserDefaults.standard.object(forKey: Self.autoKey) as? Bool ?? false
    }

    var active: Profile? { profiles.first { $0.id == activeID } }

    func activate(_ profile: Profile) {
        activeID = profile.id
        applyLayout?(profile.slots)
    }

    /// Store the current live layout back into the active profile.
    func captureLayout(_ slots: [DashboardWidgetKind]) {
        guard let idx = profiles.firstIndex(where: { $0.id == activeID }) else { return }
        profiles[idx].slots = slots
    }

    /// Pick the profile that rules say should be active right now, if auto-switch
    /// is on. Focus match wins over schedule match.
    func resolveAutomatic(now: Date, focus: String?) -> Profile? {
        guard autoSwitch else { return nil }
        if let focus, let byFocus = profiles.first(where: { $0.focusName == focus }) {
            return byFocus
        }
        return profiles.first { $0.schedule?.contains(now) == true }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.profilesKey)
        }
    }
}

/// Best-effort reader of the currently active macOS Focus.
///
/// There is no public API, so this polls the Focus assertions file. It fails
/// silently (returns `nil`) when the file isn't readable, which is fine — the
/// schedule rules still work.
@MainActor
final class FocusMonitor: ObservableObject {
    @Published private(set) var current: String?

    private var timer: Timer?
    private let assertionsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")

    func start() {
        read()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read() }
        }
    }

    private func read() {
        guard
            let data = try? Data(contentsOf: assertionsURL),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let records = (json["data"] as? [[String: Any]])?.first?["storeAssertionRecords"] as? [[String: Any]]
        else { current = nil; return }

        let mode = records
            .compactMap { ($0["assertionDetails"] as? [String: Any])?["assertionDetailsModeIdentifier"] as? String }
            .first
        // The identifier looks like "com.apple.focus.work" — take the last path component.
        current = mode?.split(separator: ".").last.map(String.init)
    }
}
