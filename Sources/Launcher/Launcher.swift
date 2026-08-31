import AppKit
import Combine

struct LaunchItem: Identifiable, Hashable {
    let id: String        // full path
    let name: String
    let url: URL

    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

/// Persists launcher configuration: extra folders to scan and the display mode.
@MainActor
final class LauncherStore: ObservableObject {
    enum DisplayMode: String, CaseIterable, Codable { case grid, list }

    private static let foldersKey = "launcher.extraFolders.v1"
    private static let modeKey = "launcher.mode.v1"

    @Published var extraFolders: [URL] {
        didSet {
            UserDefaults.standard.set(extraFolders.map(\.path), forKey: Self.foldersKey)
        }
    }
    @Published var mode: DisplayMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.modeKey) }
    }

    init() {
        extraFolders = (UserDefaults.standard.stringArray(forKey: Self.foldersKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
        mode = DisplayMode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .grid
    }

    func addFolder(_ url: URL) {
        guard !extraFolders.contains(url) else { return }
        extraFolders.append(url)
    }

    func removeFolder(_ url: URL) {
        extraFolders.removeAll { $0 == url }
    }
}

/// Scans the standard application directories (plus any extra folders) and
/// publishes a de-duplicated, sorted list of launchable apps.
@MainActor
final class AppScanner: ObservableObject {
    @Published private(set) var items: [LaunchItem] = []

    private static let standardDirs: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    func rescan(extraFolders: [URL]) {
        let dirs = Self.standardDirs + extraFolders
        Task.detached(priority: .utility) {
            let found = Self.scan(dirs)
            await MainActor.run { self.items = found }
        }
    }

    nonisolated private static func scan(_ dirs: [URL]) -> [LaunchItem] {
        let fm = FileManager.default
        var byName: [String: LaunchItem] = [:]
        for dir in dirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) else { continue }
            for url in entries where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                byName[name] = LaunchItem(id: url.path, name: name, url: url)
            }
        }
        return byName.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Lists and runs macOS Shortcuts via the `shortcuts` CLI.
@MainActor
final class ShortcutsService: ObservableObject {
    @Published private(set) var names: [String] = []

    nonisolated private static let cli = "/usr/bin/shortcuts"

    func reload() {
        Task.detached(priority: .utility) {
            let output = Self.run(["list"])
            let parsed = output
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            await MainActor.run { self.names = parsed }
        }
    }

    func run(_ name: String) {
        Task.detached(priority: .userInitiated) {
            _ = Self.run(["run", name])
        }
    }

    nonisolated private static func run(_ args: [String]) -> String {
        guard FileManager.default.isExecutableFile(atPath: cli) else { return "" }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cli)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

enum Launcher {
    /// Prompt the user to pick a folder (accessory apps must activate first).
    @MainActor
    static func chooseFolder() -> URL? {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add"
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func open(_ item: LaunchItem) {
        NSWorkspace.shared.open(item.url)
    }

    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
