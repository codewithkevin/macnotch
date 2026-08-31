import Foundation

/// The widgets that can occupy a dashboard slot. Phase A ships four of them;
/// later phases append cases (launcher, quick toggles, mirror, …).
enum DashboardWidgetKind: String, Codable, CaseIterable, Identifiable {
    case dayProgress
    case quote
    case weather
    case shelf
    case battery
    case appLauncher
    case shortcuts
    case empty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dayProgress: return "Day Progress"
        case .quote:       return "Quote"
        case .weather:     return "Weather"
        case .shelf:       return "Shelf"
        case .battery:     return "Battery"
        case .appLauncher: return "App Launcher"
        case .shortcuts:   return "Shortcuts"
        case .empty:       return "Empty"
        }
    }

    var symbol: String {
        switch self {
        case .dayProgress: return "clock.arrow.circlepath"
        case .quote:       return "quote.opening"
        case .weather:     return "cloud.sun"
        case .shelf:       return "tray.full"
        case .battery:     return "battery.100"
        case .appLauncher: return "square.grid.3x3.fill"
        case .shortcuts:   return "bolt.fill"
        case .empty:       return "square.dashed"
        }
    }
}
