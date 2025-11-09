import Foundation

struct WeatherService {
    func fetchWeather(for region: String? = nil) -> WeatherType {
        // Deterministic stub: hash region to pick a weather; fallback to sunny
        if let region, !region.isEmpty {
            let h = abs(region.hashValue)
            let all = WeatherType.allCases
            return all[h % all.count]
        }
        return .sunny
    }

    func fetchWeather() -> WeatherType {
        return fetchWeather(for: nil)
    }
}
