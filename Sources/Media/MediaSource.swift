import SwiftUI

/// A known media player. Used to give the Now Playing panel a per-app accent and
/// icon, and to show which sources are installed.
struct MediaSource: Identifiable {
    var id: String { bundleID }
    let name: String
    let bundleID: String
    let tint: Color
    let fallbackSymbol: String

    var installedURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }
    var isInstalled: Bool { installedURL != nil }
    var icon: NSImage? {
        installedURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    static let known: [MediaSource] = [
        .init(name: "Spotify",           bundleID: "com.spotify.client",        tint: Color(red: 0.11, green: 0.73, blue: 0.33), fallbackSymbol: "music.note"),
        .init(name: "Apple Music",       bundleID: "com.apple.Music",           tint: Color(red: 0.98, green: 0.24, blue: 0.35), fallbackSymbol: "music.note"),
        .init(name: "Plex",              bundleID: "tv.plex.desktop",           tint: Color(red: 0.90, green: 0.62, blue: 0.00), fallbackSymbol: "play.tv"),
        .init(name: "Plex",              bundleID: "com.plexapp.plexmediaplayer", tint: Color(red: 0.90, green: 0.62, blue: 0.00), fallbackSymbol: "play.tv"),
        .init(name: "NetEase Music",     bundleID: "com.netease.163music",      tint: Color(red: 0.85, green: 0.13, blue: 0.13), fallbackSymbol: "music.note"),
        .init(name: "VLC",               bundleID: "org.videolan.vlc",          tint: Color(red: 0.94, green: 0.50, blue: 0.09), fallbackSymbol: "film"),
        .init(name: "Music",             bundleID: "com.apple.MobileSMS",       tint: .gray, fallbackSymbol: "music.note"),
        .init(name: "Safari",            bundleID: "com.apple.Safari",          tint: Color(red: 0.10, green: 0.52, blue: 0.96), fallbackSymbol: "safari"),
        .init(name: "Chrome",            bundleID: "com.google.Chrome",         tint: Color(red: 0.26, green: 0.52, blue: 0.96), fallbackSymbol: "globe"),
        .init(name: "Arc",               bundleID: "company.thebrowser.Browser", tint: Color(red: 0.98, green: 0.36, blue: 0.42), fallbackSymbol: "globe"),
        .init(name: "Firefox",           bundleID: "org.mozilla.firefox",       tint: Color(red: 1.00, green: 0.35, blue: 0.13), fallbackSymbol: "globe"),
    ]

    static func match(bundleID: String?) -> MediaSource? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        return known.first { $0.bundleID.caseInsensitiveCompare(bundleID) == .orderedSame }
    }

    /// The subset of `known` that is actually installed (de-duped by name).
    static var installed: [MediaSource] {
        var seen = Set<String>()
        return known.filter { $0.isInstalled && seen.insert($0.name).inserted }
    }
}
