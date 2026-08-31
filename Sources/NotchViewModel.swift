import SwiftUI
import Combine

@MainActor
final class NotchViewModel: ObservableObject {
    @Published var metrics: NotchMetrics = .current()
    @Published var isExpanded: Bool = false {
        didSet { if isExpanded != oldValue { onExpandedChange?(isExpanded) } }
    }

    /// Notifies the AppKit interaction layer so its tracking rect stays in sync.
    var onExpandedChange: ((Bool) -> Void)?
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

    private var autoCollapse: Task<Void, Never>?

    func setExpanded(_ expanded: Bool) {
        autoCollapse?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isExpanded = expanded
        }
    }

    /// Open via a gesture (scroll), with a fallback that re-collapses if the
    /// pointer never enters the panel to take over the hover state.
    func expandFromGesture() {
        setExpanded(true)
        autoCollapse = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.setExpanded(false)
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
