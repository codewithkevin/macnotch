import SwiftUI
import Combine
import MediaRemoteAdapter

/// System-wide now-playing state + transport controls.
///
/// Backed by `MediaRemoteAdapter`, which reads Apple's private `MediaRemote`
/// framework through an entitled system binary (`/usr/bin/perl`). This means it
/// sees *any* app that reports to the macOS Now Playing center: Music, Spotify,
/// podcasts, and browser media sessions in Safari / Chrome / Arc / Firefox.
@MainActor
final class NowPlayingController: ObservableObject {

    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        var appName: String
        var bundleID: String
        var isPlaying: Bool
        var duration: TimeInterval          // seconds, 0 if unknown
        var artwork: NSImage?

        static func == (lhs: Track, rhs: Track) -> Bool {
            lhs.title == rhs.title && lhs.artist == rhs.artist &&
            lhs.album == rhs.album && lhs.isPlaying == rhs.isPlaying &&
            lhs.duration == rhs.duration
        }
    }

    @Published private(set) var track: Track?
    /// Interpolated playback position in seconds.
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var shuffle: TrackInfo.ShuffleMode = .off
    @Published private(set) var repeatMode: TrackInfo.RepeatMode = .off

    var hasMedia: Bool { track != nil }
    var isShuffling: Bool { shuffle != .off }
    /// SF Symbol for the repeat button + whether it should read as "on".
    var repeatSymbol: String { repeatMode == .one ? "repeat.1" : "repeat" }
    var isRepeating: Bool { repeatMode != .off }
    var progress: Double {
        guard let d = track?.duration, d > 0 else { return 0 }
        return min(max(elapsed / d, 0), 1)
    }

    private let controller = MediaController()
    private var ticker: AnyCancellable?
    /// Position reported at the last state change, and when it was measured.
    private var anchorElapsed: TimeInterval = 0
    private var anchorDate: Date = .now

    init() {
        controller.onTrackInfoReceived = { [weak self] info in
            Task { @MainActor in self?.ingest(info) }
        }
        controller.onListenerTerminated = { [weak self] in
            Task { @MainActor in self?.restart() }
        }
    }

    func start() {
        controller.startListening()
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func restart() {
        controller.stopListening()
        controller.startListening()
    }

    // MARK: - Transport

    func togglePlayPause() { controller.togglePlayPause() }
    func next() { controller.nextTrack() }
    func previous() { controller.previousTrack() }

    func toggleShuffle() {
        // off -> songs -> off
        let next: TrackInfo.ShuffleMode = shuffle == .off ? .songs : .off
        shuffle = next
        controller.setShuffleMode(next)
    }

    func cycleRepeat() {
        // off -> all -> one -> off
        let next: TrackInfo.RepeatMode
        switch repeatMode {
        case .off: next = .all
        case .all: next = .one
        case .one: next = .off
        }
        repeatMode = next
        controller.setRepeatMode(next)
    }

    func like() { controller.likeTrack() }

    /// Seek to a fraction (0...1) of the current track.
    func seek(toFraction fraction: Double) {
        guard let d = track?.duration, d > 0 else { return }
        let seconds = min(max(fraction, 0), 1) * d
        controller.setTime(seconds: seconds)
        anchorElapsed = seconds
        anchorDate = .now
        elapsed = seconds
    }

    // MARK: - Ingest

    private func ingest(_ info: TrackInfo?) {
        guard let payload = info?.payload, let title = payload.title, !title.isEmpty else {
            track = nil
            elapsed = 0
            return
        }

        let duration = (payload.durationMicros ?? 0) / 1_000_000
        track = Track(
            title: title,
            artist: payload.artist ?? "",
            album: payload.album ?? "",
            appName: payload.applicationName ?? "",
            bundleID: payload.bundleIdentifier ?? "",
            isPlaying: payload.isPlaying ?? false,
            duration: duration,
            artwork: payload.artwork
        )

        if let s = payload.shuffleMode { shuffle = s }
        if let r = payload.repeatMode { repeatMode = r }

        anchorElapsed = payload.currentElapsedTime ?? payload.elapsedTimeMicros.map { $0 / 1_000_000 } ?? 0
        anchorDate = .now
        elapsed = anchorElapsed
    }

    private func tick() {
        guard let track, track.isPlaying else { return }
        let projected = anchorElapsed + Date.now.timeIntervalSince(anchorDate)
        elapsed = track.duration > 0 ? min(projected, track.duration) : projected
    }
}

extension TimeInterval {
    /// `m:ss` formatting for playback times.
    var clockString: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let total = Int(self)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
