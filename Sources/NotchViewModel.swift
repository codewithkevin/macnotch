import SwiftUI
import Combine

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var metrics: NotchMetrics = .current()
    @Published var isExpanded: Bool = false
    @Published var now: Date = Date()
    /// File URLs dropped onto the shelf.
    @Published var shelfItems: [URL] = [] {
        didSet { ShelfStore.save(shelfItems) }
    }

    private var timer: AnyCancellable?

    init() {
        shelfItems = ShelfStore.load()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }

    func setExpanded(_ expanded: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = expanded
        }
    }

    func addToShelf(_ urls: [URL]) {
        for url in urls where !shelfItems.contains(url) {
            shelfItems.append(url)
        }
    }

    func removeFromShelf(_ url: URL) {
        shelfItems.removeAll { $0 == url }
    }

    func clearShelf() { shelfItems.removeAll() }
}
