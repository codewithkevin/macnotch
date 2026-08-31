import SwiftUI

/// Persists the 2×2 dashboard layout (four slots) as JSON in `UserDefaults`.
@MainActor
final class DashboardStore: ObservableObject {
    private static let key = "dashboard.slots.v1"
    static let slotCount = 4

    @Published var slots: [DashboardWidgetKind] {
        didSet { persist() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([DashboardWidgetKind].self, from: data),
           decoded.count == Self.slotCount {
            slots = decoded
        } else {
            slots = [.dayProgress, .weather, .quote, .shelf]
        }
    }

    func setSlot(_ index: Int, to kind: DashboardWidgetKind) {
        guard slots.indices.contains(index) else { return }
        // Keep slots unique (except .empty) — swap if the kind is already placed.
        if kind != .empty, let existing = slots.firstIndex(of: kind) {
            slots[existing] = slots[index]
        }
        slots[index] = kind
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(slots) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
