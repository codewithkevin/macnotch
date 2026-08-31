import SwiftUI

/// Fetches current conditions from Open-Meteo (no API key). Location is resolved
/// coarsely by IP via ipwho.is so Phase A needs no CoreLocation permission —
/// CoreLocation can be added later for accuracy.
@MainActor
final class WeatherService: ObservableObject {

    struct Conditions: Equatable {
        var place: String
        var temperature: Double
        var high: Double
        var low: Double
        var code: Int
        var isDay: Bool

        var symbol: String { WeatherService.symbol(for: code, isDay: isDay) }
        var summary: String { WeatherService.summary(for: code) }
    }

    @Published private(set) var conditions: Conditions?
    @Published private(set) var lastError: String?

    private var timer: Timer?

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        do {
            let loc = try await fetchLocation()
            let c = try await fetchWeather(lat: loc.lat, lon: loc.lon, place: loc.city)
            conditions = c
            lastError = nil
        } catch {
            lastError = "Weather unavailable"
        }
    }

    // MARK: - Networking

    private struct IPLocation: Decodable {
        let latitude: Double
        let longitude: Double
        let city: String?
    }

    private func fetchLocation() async throws -> (lat: Double, lon: Double, city: String) {
        let url = URL(string: "https://ipwho.is/?fields=latitude,longitude,city")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(IPLocation.self, from: data)
        return (decoded.latitude, decoded.longitude, decoded.city ?? "")
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double]
            let temperature_2m_min: [Double]
        }
        let current: Current
        let daily: Daily
    }

    private func fetchWeather(lat: Double, lon: Double, place: String) async throws -> Conditions {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "1"),
        ]
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let r = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return Conditions(
            place: place,
            temperature: r.current.temperature_2m,
            high: r.daily.temperature_2m_max.first ?? r.current.temperature_2m,
            low: r.daily.temperature_2m_min.first ?? r.current.temperature_2m,
            code: r.current.weather_code,
            isDay: r.current.is_day == 1
        )
    }

    // MARK: - WMO code mapping

    nonisolated static func symbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0:        return isDay ? "sun.max" : "moon.stars"
        case 1, 2:     return isDay ? "cloud.sun" : "cloud.moon"
        case 3:        return "cloud"
        case 45, 48:   return "cloud.fog"
        case 51...57:  return "cloud.drizzle"
        case 61...67:  return "cloud.rain"
        case 71...77:  return "cloud.snow"
        case 80...82:  return "cloud.heavyrain"
        case 85, 86:   return "cloud.snow"
        case 95...99:  return "cloud.bolt.rain"
        default:       return "cloud"
        }
    }

    nonisolated static func summary(for code: Int) -> String {
        switch code {
        case 0:        return "Clear"
        case 1, 2:     return "Partly cloudy"
        case 3:        return "Overcast"
        case 45, 48:   return "Fog"
        case 51...57:  return "Drizzle"
        case 61...67:  return "Rain"
        case 71...77:  return "Snow"
        case 80...82:  return "Showers"
        case 85, 86:   return "Snow showers"
        case 95...99:  return "Thunderstorm"
        default:       return "—"
        }
    }
}
