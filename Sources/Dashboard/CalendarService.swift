import SwiftUI
import EventKit

/// Upcoming calendar events via EventKit. Needs `NSCalendarsFullAccessUsageDescription`
/// (macOS 14+); degrades to an empty list if access is denied.
@MainActor
final class CalendarService: ObservableObject {

    struct Event: Identifiable {
        let id: String
        let title: String
        let start: Date
        let isAllDay: Bool
        let color: Color
    }

    enum Access { case unknown, granted, denied }

    @Published private(set) var events: [Event] = []
    @Published private(set) var access: Access = .unknown

    private let store = EKEventStore()
    private var timer: Timer?

    func start() {
        Task { await requestAndLoad() }
        timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.load() }
        }
    }

    private func requestAndLoad() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            access = granted ? .granted : .denied
            if granted { load() }
        } catch {
            access = .denied
        }
    }

    private func load() {
        guard access == .granted else { return }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 2, to: now)!
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { ($0.endDate ?? $0.startDate) >= now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(4)
            .map {
                Event(id: $0.eventIdentifier ?? UUID().uuidString,
                      title: $0.title ?? "(No title)",
                      start: $0.startDate,
                      isAllDay: $0.isAllDay,
                      color: Color(nsColor: $0.calendar.color ?? .systemBlue))
            }
    }
}
