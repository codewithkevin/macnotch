import Foundation

/// Persists shelf file references across launches using security-scoped
/// bookmarks, so they survive the file being moved or renamed and keep working
/// even if the app is later sandboxed.
enum ShelfStore {
    private static let key = "shelf.bookmarks"

    static func load() -> [URL] {
        guard let raw = UserDefaults.standard.array(forKey: key) as? [Data] else { return [] }
        var urls: [URL] = []
        var stillValid: [Data] = []
        for data in raw {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: [.withoutUI],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &stale) else { continue }
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            urls.append(url)
            // Refresh stale bookmarks so they don't rot further.
            if stale, let fresh = try? url.bookmarkData(options: [.minimalBookmark]) {
                stillValid.append(fresh)
            } else {
                stillValid.append(data)
            }
        }
        if stillValid.count != raw.count {
            UserDefaults.standard.set(stillValid, forKey: key)
        }
        return urls
    }

    static func save(_ urls: [URL]) {
        let data = urls.compactMap { try? $0.bookmarkData(options: [.minimalBookmark]) }
        UserDefaults.standard.set(data, forKey: key)
    }
}
