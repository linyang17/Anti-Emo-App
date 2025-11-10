import Foundation
import CoreLocation
import OSLog
#if canImport(WeatherKit)
import WeatherKit
#endif

@MainActor
final class WeatherService: ObservableObject {
    private let log = Logger(subsystem: "com.sunny.pet", category: "WeatherService")
#if canImport(WeatherKit)
    @available(iOS 16.0, *)
    private let weatherService = WeatherKit.WeatherService()
#endif

    func requestAuthorization() async -> Bool {
#if canImport(WeatherKit)
        if #available(iOS 16.4, *) {
            let manager = WeatherAuthorizationManager.shared
            let status = manager.authorizationStatus
            if status == .notDetermined {
                do {
                    let result = try await manager.requestAuthorization()
                    return result == .authorized
                } catch {
                    log.error("Weather authorization request failed: \(error.localizedDescription, privacy: .public)")
                    return false
                }
            }
            return status == .authorized
        }
#endif
        return true
    }

    func fetchWeather(for location: CLLocation?, locality: String?) async -> WeatherReport {
        guard let location else {
            return fallbackReport(locality: locality)
        }
#if canImport(WeatherKit)
        if #available(iOS 16.0, *) {
            do {
                let weather = try await weatherService.weather(for: location)
                let current = WeatherType(from: weather.currentWeather)
                let windows = buildWindows(weather: weather)
                return WeatherReport(location: location, locality: locality, currentWeather: current, windows: windows)
            } catch {
                log.error("WeatherKit fetch failed: \(error.localizedDescription, privacy: .public)")
                return fallbackReport(locality: locality)
            }
        }
#endif
        return fallbackReport(locality: locality)
    }

    #if canImport(WeatherKit)
    @available(iOS 16.0, *)
    private func buildWindows(weather: Weather) -> [WeatherWindow] {
        var windows: [WeatherWindow] = []
        if let minute = weather.minuteForecast?.forecast, !minute.isEmpty {
            windows = buildMinuteWindows(minute)
        } else if let hourly = weather.hourlyForecast?.forecast {
            windows = hourly.map { hour in
                WeatherWindow(
                    startDate: hour.date,
                    endDate: hour.date.addingTimeInterval(3600),
                    weather: WeatherType(from: hour)
                )
            }
        }
        if windows.isEmpty {
            let current = weather.currentWeather
            let start = current.date
            let end = start.addingTimeInterval(3600)
            windows = [WeatherWindow(startDate: start, endDate: end, weather: WeatherType(from: current))]
        }
        return mergeAdjacentWindows(windows)
    }

    private func buildMinuteWindows(_ minute: [MinuteWeather]) -> [WeatherWindow] {
        guard let first = minute.first else { return [] }
        var windows: [WeatherWindow] = []
        var currentCondition = WeatherType(from: first)
        var windowStart = first.date

        for entry in minute.dropFirst() {
            let condition = WeatherType(from: entry)
            if condition != currentCondition {
                let window = WeatherWindow(
                    startDate: windowStart,
                    endDate: entry.date,
                    weather: currentCondition
                )
                windows.append(window)
                windowStart = entry.date
                currentCondition = condition
            }
        }
        if let lastDate = minute.last?.date {
            windows.append(
                WeatherWindow(
                    startDate: windowStart,
                    endDate: lastDate,
                    weather: currentCondition
                )
            )
        }
        return windows
    }

    private func mergeAdjacentWindows(_ windows: [WeatherWindow]) -> [WeatherWindow] {
        guard !windows.isEmpty else { return [] }
        var merged: [WeatherWindow] = []
        var current = windows[0]

        for window in windows.dropFirst() {
            if window.weather == current.weather && window.startDate <= current.endDate.addingTimeInterval(60) {
                current = WeatherWindow(
                    id: current.id,
                    startDate: current.startDate,
                    endDate: max(current.endDate, window.endDate),
                    weather: current.weather
                )
            } else {
                merged.append(current)
                current = window
            }
        }
        merged.append(current)
        return merged
    }
    #endif

    private func fallbackReport(locality: String?) -> WeatherReport {
        let now = Date()
        let calendar = TimeZoneManager.shared.calendar
        let startOfDay = calendar.startOfDay(for: now)
        let windows = [
            WeatherWindow(
                startDate: startOfDay,
                endDate: calendar.date(byAdding: .hour, value: 5, to: startOfDay) ?? startOfDay.addingTimeInterval(18_000),
                weather: .sunny
            ),
            WeatherWindow(
                startDate: calendar.date(byAdding: .hour, value: 5, to: startOfDay) ?? startOfDay.addingTimeInterval(18_000),
                endDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay.addingTimeInterval(43_200),
                weather: .cloudy
            ),
            WeatherWindow(
                startDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay.addingTimeInterval(43_200),
                endDate: calendar.date(byAdding: .hour, value: 18, to: startOfDay) ?? startOfDay.addingTimeInterval(64_800),
                weather: .rainy
            )
        ]
        return WeatherReport(location: nil, locality: locality, currentWeather: .sunny, windows: windows)
    }
}

#if canImport(WeatherKit)
@available(iOS 16.0, *)
private extension WeatherType {
    init(from current: CurrentWeather) {
        self = WeatherType.map(condition: current.condition)
    }

    init(from hour: HourWeather) {
        self = WeatherType.map(condition: hour.condition)
    }

    init(from minute: MinuteWeather) {
        self = WeatherType.map(condition: minute.condition)
    }

    static func map(condition: WeatherCondition) -> WeatherType {
        switch condition {
        case .blizzard, .snow, .flurries, .hail, .freezingDrizzle, .freezingRain:
            return .snowy
        case .blowingDust, .blowingSnow, .breezy, .windy:
            return .windy
        case .cloudy, .mostlyCloudy, .partlyCloudy, .fog, .haze:
            return .cloudy
        case .clear, .mostlyClear:
            return .sunny
        case .drizzle, .rain, .heavyRain, .thunderstorms, .tropicalStorm:
            return .rainy
        default:
            return .cloudy
        }
    }
}
#endif
