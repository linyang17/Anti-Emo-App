
import Foundation
import CoreLocation
import WeatherKit
import Combine
import OSLog

// MARK: - Codable Snapshots for Persistence
private struct WeatherReportSnapshot: Codable {
        let latitude: Double?
        let longitude: Double?
        let locality: String?
        let current: String // WeatherType rawValue
        let windows: [WeatherWindowSnapshot]
        let sunEvents: [SunEventSnapshot]?
        let timestamp: Date
}

private struct WeatherWindowSnapshot: Codable {
        let startDate: Date
        let endDate: Date
        let weather: String // WeatherType rawValue
}

private struct SunEventSnapshot: Codable {
        let day: Date
        let sunrise: Date
        let sunset: Date
}

// MARK: - WeatherService (MainActor)
@MainActor
final class WeatherService: ObservableObject {
	private let log = Logger(subsystem: "com.Lumio.pet", category: "WeatherService")

	// MARK: - Published Observables
	@Published var currentWeatherReport: WeatherReport?
	@Published var isAuthorized: Bool = false

	// MARK: - Managers
	private let locationManager = CLLocationManager()
	private let weatherService = WeatherKit.WeatherService.shared

	// MARK: - Lightweight Cache & Policy
	private let cacheKey = "WeatherService.cachedReport"
	private let cacheTTL: TimeInterval = 60 * 30 // 30 minutes
	private let distanceThreshold: CLLocationDistance = 20_000 // 20km
	private var lastFetchAt: Date?
	private var lastFetchedCoordinate: CLLocationCoordinate2D?

	// MARK: - Initialization
	init() {
		restoreFromDisk()
	}

	// MARK: - Location Authorization
	@discardableResult
	func checkLocationAuthorization() async -> Bool {
		let status = locationManager.authorizationStatus
		switch status {
		case .notDetermined:
			locationManager.requestWhenInUseAuthorization()
			try? await Task.sleep(nanoseconds: 500_000_000) // allow status to update
			isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse ||
						   locationManager.authorizationStatus == .authorizedAlways
		case .authorizedWhenInUse, .authorizedAlways:
			isAuthorized = true
		default:
			isAuthorized = false
		}
		return isAuthorized
	}

	// MARK: - Public API
	/// Fetches weather and builds a WeatherReport. Uses TTL+distance cache; falls back to snapshot when needed.
	func fetchWeather(for location: CLLocation?, locality: String?) async -> WeatherReport {
		// No location -> return fallback (do not clear cache)
		guard let location else {
			let fb = fallbackReport(locality: locality)
			currentWeatherReport = fb
			return fb
		}

		// Ensure authorization
		guard isAuthorized else {
			log.warning("Weather fetch attempted before authorization.")
			let fb = fallbackReport(locality: locality)
			currentWeatherReport = fb
			return fb
		}

		// Cache policy: distance + TTL
		if let last = lastFetchedCoordinate,
		   let lastAt = lastFetchAt {
			let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
			let withinDistance = location.distance(from: lastLoc) <= distanceThreshold
			let withinTTL = Date().timeIntervalSince(lastAt) < cacheTTL
			if withinDistance && withinTTL, let cached = currentWeatherReport {
				// Serve memory cache
				return cached
			}
		}

		// Remote fetch via WeatherKit
                do {
					let weather = try await weatherService.weather(for: location)
					let current = WeatherType(from: weather.currentWeather)
					let windows = buildWindows(weather: weather)
					let sunEvents = buildSunEvents(weather: weather)
					let report = WeatherReport(location: location, locality: locality, currentWeather: current, windows: windows, sunEvents: sunEvents)

			// Update memory + persistence
			currentWeatherReport = report
			lastFetchAt = Date()
			lastFetchedCoordinate = location.coordinate
			persistToDisk(report)
			return report
		} catch {
			log.error("WeatherKit fetch failed: \(error.localizedDescription, privacy: .public)")
			// Fallback to snapshot if available
			if let snapshotReport = restoreFromDisk() {
				currentWeatherReport = snapshotReport
				return snapshotReport
			}
			let fb = fallbackReport(locality: locality)
			currentWeatherReport = fb
			return fb
		}
	}

	/// Convenience: respects cache policy and returns cached if valid; otherwise fetches.
	func fetchIfNeeded(for location: CLLocation?, locality: String?) async -> WeatherReport {
		// If we already have a fresh report in memory and no distance jump, return it
		if let location, let last = lastFetchedCoordinate, let lastAt = lastFetchAt, let cached = currentWeatherReport {
			let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
			let withinDistance = location.distance(from: lastLoc) <= distanceThreshold
			let withinTTL = Date().timeIntervalSince(lastAt) < cacheTTL
			if withinDistance && withinTTL { return cached }
		}
		return await fetchWeather(for: location, locality: locality)
	}

	// MARK: - Window Builders (retain your existing logic)
	private func buildWindows(weather: Weather) -> [WeatherWindow] {
		// 1️⃣ Prefer minute forecast when available
		if let minuteForecast = weather.minuteForecast?.forecast, !minuteForecast.isEmpty {
			let inferredWindows = buildMinuteWindows(minuteForecast)
			let hasRain = inferredWindows.contains { $0.weather == .rainy || $0.weather == .snowy }
			if hasRain {
				return mergeAdjacentWindows(inferredWindows)
			}
		}
		// 2️⃣ Hourly fallback
		let hourly = weather.hourlyForecast.forecast
		let hourWindows = hourly.map {
			WeatherWindow(
				startDate: $0.date,
				endDate: $0.date.addingTimeInterval(3600),
				weather: WeatherType(from: $0)
			)
		}
		if hourWindows.isEmpty {
			let current = weather.currentWeather
			let start = current.date
			let end = start.addingTimeInterval(3600)
			return [WeatherWindow(startDate: start, endDate: end, weather: WeatherType(from: current))]
		}
		return mergeAdjacentWindows(hourWindows)
	}

	private func buildMinuteWindows(_ minutes: [MinuteWeather]) -> [WeatherWindow] {
		guard let first = minutes.first else { return [] }
		var windows: [WeatherWindow] = []
		var currentCondition = inferWeather(from: first)
		var windowStart = first.date
		for entry in minutes.dropFirst() {
			let inferred = inferWeather(from: entry)
			if inferred != currentCondition {
				windows.append(WeatherWindow(startDate: windowStart, endDate: entry.date, weather: currentCondition))
				windowStart = entry.date
				currentCondition = inferred
			}
		}
		if let lastDate = minutes.last?.date {
			windows.append(WeatherWindow(startDate: windowStart, endDate: lastDate, weather: currentCondition))
		}
		return windows
	}

	// MARK: - Minute-level inference (conservative & stable)
	private func inferWeather(from minute: MinuteWeather) -> WeatherType {
		let intensity = minute.precipitationIntensity.value // mm/hr
		let chance = minute.precipitationChance // 0.0 ~ 1.0
		// 优先依据强度判断降水，其次用概率做弱雨提示；否则视为晴/多云
		if intensity > 0.0 { return .rainy }
		if chance >= 0.6 { return .cloudy } // 高概率但强度未达阈值 → 多云/可能降水
		return .sunny
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

        private func buildSunEvents(weather: Weather) -> [Date: SunTimes] {
                let calendar = TimeZoneManager.shared.calendar
                let daily = weather.dailyForecast.forecast
                var events: [Date: SunTimes] = [:]
                for day in daily {
					if let sunrise = day.sun.sunrise, let sunset = day.sun.sunset {
                                let key = calendar.startOfDay(for: sunrise)
                                events[key] = SunTimes(sunrise: sunrise, sunset: sunset)
                        }
                }
                return events
        }

        // MARK: - Fallback
        private func fallbackReport(locality: String?) -> WeatherReport {
		let now = Date()
                let calendar = TimeZoneManager.shared.calendar
		let startOfDay = calendar.startOfDay(for: now)
                let windows = [
                        WeatherWindow(startDate: startOfDay,
                                                  endDate: calendar.date(byAdding: .hour, value: 5, to: startOfDay) ?? startOfDay.addingTimeInterval(18_000),
                                                  weather: .sunny),
                        WeatherWindow(startDate: calendar.date(byAdding: .hour, value: 5, to: startOfDay) ?? startOfDay.addingTimeInterval(18_000),
                                                  endDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay.addingTimeInterval(43_200),
                                                  weather: .cloudy),
                        WeatherWindow(startDate: calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay.addingTimeInterval(43_200),
                                                  endDate: calendar.date(byAdding: .hour, value: 18, to: startOfDay) ?? startOfDay.addingTimeInterval(64_800),
                                                  weather: .rainy)
                ]
                let sunrise = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: startOfDay) ?? startOfDay.addingTimeInterval(23_400)
                let sunset = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: startOfDay) ?? startOfDay.addingTimeInterval(66_600)
                let events = [startOfDay: SunTimes(sunrise: sunrise, sunset: sunset)]
                return WeatherReport(location: nil, locality: locality, currentWeather: .sunny, windows: windows, sunEvents: events)
        }

	// MARK: - Persistence (Snapshot <-> Domain)
	private func persistToDisk(_ report: WeatherReport) {
                let snap = WeatherReportSnapshot(
                        latitude: report.location?.coordinate.latitude,
                        longitude: report.location?.coordinate.longitude,
                        locality: report.locality,
                        current: report.currentWeather.rawValue,
                        windows: report.windows.map { WeatherWindowSnapshot(startDate: $0.startDate, endDate: $0.endDate, weather: $0.weather.rawValue) },
                        sunEvents: report.sunEvents.map { SunEventSnapshot(day: $0.key, sunrise: $0.value.sunrise, sunset: $0.value.sunset) },
                        timestamp: Date()
                )
		do {
			let data = try JSONEncoder().encode(snap)
			UserDefaults.standard.set(data, forKey: cacheKey)
		} catch {
			log.error("Failed to persist weather snapshot: \(error.localizedDescription, privacy: .public)")
		}
	}

	@discardableResult
	private func restoreFromDisk() -> WeatherReport? {
		guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
		do {
			let snap = try JSONDecoder().decode(WeatherReportSnapshot.self, from: data)
			let loc: CLLocation? = {
				if let lat = snap.latitude, let lon = snap.longitude {
					return CLLocation(latitude: lat, longitude: lon)
				}
				return nil
			}()
                        let cal = TimeZoneManager.shared.calendar
                        let sunEvents = Dictionary(uniqueKeysWithValues: (snap.sunEvents ?? []).map { snapshot in
                                (cal.startOfDay(for: snapshot.day), SunTimes(sunrise: snapshot.sunrise, sunset: snapshot.sunset))
                        })
                        let report = WeatherReport(
                                location: loc,
                                locality: snap.locality,
                                currentWeather: WeatherType(rawValue: snap.current) ?? .cloudy,
                                windows: snap.windows.map { WeatherWindow(startDate: $0.startDate, endDate: $0.endDate, weather: WeatherType(rawValue: $0.weather) ?? .cloudy) },
                                sunEvents: sunEvents
                        )
			currentWeatherReport = report
			lastFetchAt = snap.timestamp
			if let lat = snap.latitude, let lon = snap.longitude {
				lastFetchedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
			}
			return report
		} catch {
			log.error("Failed to restore weather snapshot: \(error.localizedDescription, privacy: .public)")
			return nil
		}
	}
}

// MARK: - WeatherType Conversion (unchanged)
private extension WeatherType {
	init(from current: CurrentWeather) {
		self = WeatherType.map(condition: current.condition)
	}
	init(from hour: HourWeather) {
		self = WeatherType.map(condition: hour.condition)
	}

	static func map(condition: WeatherCondition) -> WeatherType {
		switch condition {
		case .blizzard, .snow, .flurries, .hail, .freezingDrizzle, .freezingRain, .blowingSnow:
			return .snowy
		case .blowingDust, .breezy, .windy:
			return .windy
		case .cloudy, .mostlyCloudy, .partlyCloudy, .haze:
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
