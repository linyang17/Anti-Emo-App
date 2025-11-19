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
	let current: String
	let windows: [WeatherWindowSnapshot]
	let sunEvents: [SunEventSnapshot]?
	let timestamp: Date
}

private struct WeatherWindowSnapshot: Codable {
	let startDate: Date
	let endDate: Date
	let weather: String
}

private struct SunEventSnapshot: Codable {
	let day: Date
	let sunrise: Date
	let sunset: Date
}

// MARK: - WeatherService (MainActor)
@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
	// MARK: - Logging
	private let log = Logger(subsystem: "com.selena.AntiEmoPet", category: "WeatherService")

	// MARK: - Published Observables
	@Published private(set) var currentWeatherReport: WeatherReport?
	@Published private(set) var isAuthorized: Bool = false

	// MARK: - Managers
	private let locationManager = CLLocationManager()
	private let weatherService = WeatherKit.WeatherService.shared

	// MARK: - Cache Policy
	private let cacheKey = "WeatherService.cachedReport"
	private let cacheTTL: TimeInterval = 60 * 30 // 30 min
	private let distanceThreshold: CLLocationDistance = 20_000 // 20km
	private let snapshotValidity: TimeInterval = 60 * 60 * 6 // 6 hours

	private var lastFetchAt: Date?
	private var lastFetchedCoordinate: CLLocationCoordinate2D?

	// MARK: - Initialization
	override init() {
		super.init()
		locationManager.delegate = self
		restoreFromDisk()
	}

	// MARK: - Location Authorization
	@discardableResult
	func checkLocationAuthorization() async -> Bool {
		switch locationManager.authorizationStatus {
		case .notDetermined:
			locationManager.requestWhenInUseAuthorization()
			try? await Task.sleep(nanoseconds: 500_000_000)
			isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse ||
						   locationManager.authorizationStatus == .authorizedAlways
		case .authorizedWhenInUse, .authorizedAlways:
			isAuthorized = true
		default:
			isAuthorized = false
		}
		return isAuthorized
	}

	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		isAuthorized = manager.authorizationStatus == .authorizedWhenInUse ||
					   manager.authorizationStatus == .authorizedAlways
	}

	// MARK: - Fetch Weather
	func fetchWeather(for location: CLLocation?, locality: String?) async -> WeatherReport {
		guard let location else {
			let fb = fallbackReport(locality: locality)
			currentWeatherReport = fb
			return fb
		}

		guard isAuthorized else {
			log.warning("⚠️ Weather fetch attempted before authorization.")
			let fb = fallbackReport(locality: locality)
			currentWeatherReport = fb
			return fb
		}

		// Cache policy
		if let last = lastFetchedCoordinate,
		   let lastAt = lastFetchAt {
			let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
			let withinDistance = location.distance(from: lastLoc) <= distanceThreshold
			let withinTTL = Date().timeIntervalSince(lastAt) < cacheTTL

			if withinDistance && withinTTL, let cached = currentWeatherReport {
				log.debug("💾 Using in-memory cached weather report.")
				return cached
			}
		}

		// Fetch from WeatherKit
		do {
			let weather = try await weatherService.weather(for: location)
			let current = WeatherType(from: weather.currentWeather)
			let windows = buildWindows(weather: weather)
			let sunEvents = buildSunEvents(weather: weather)

			let report = WeatherReport(
				location: location,
				locality: locality,
				currentWeather: current,
				windows: windows,
				sunEvents: sunEvents
			)

			currentWeatherReport = report
			lastFetchAt = Date()
			lastFetchedCoordinate = location.coordinate
			persistToDisk(report)

			log.info("✅ WeatherKit fetch succeeded: \(current.rawValue)")
			return report

		} catch {
			log.error("❌ WeatherKit fetch failed: \(error.localizedDescription, privacy: .public)")

			if let snapshot = restoreFromDisk(), Date().timeIntervalSince(snapshot.sunEvents.first?.value.sunrise ?? .distantPast) < snapshotValidity {
				currentWeatherReport = snapshot
				return snapshot
			}

			let fb = fallbackReport(locality: locality)
			currentWeatherReport = fb
			return fb
		}
	}

	func fetchIfNeeded(for location: CLLocation?, locality: String?) async -> WeatherReport {
		if let location, let last = lastFetchedCoordinate, let lastAt = lastFetchAt, let cached = currentWeatherReport {
			let lastLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
			let withinDistance = location.distance(from: lastLoc) <= distanceThreshold
			let withinTTL = Date().timeIntervalSince(lastAt) < cacheTTL
			if withinDistance && withinTTL {
				return cached
			}
		}
		return await fetchWeather(for: location, locality: locality)
	}

	// MARK: - Window Builders
	private func buildWindows(weather: Weather) -> [WeatherWindow] {
		if let minuteForecast = weather.minuteForecast?.forecast, !minuteForecast.isEmpty {
			let inferred = buildMinuteWindows(minuteForecast)
			if inferred.contains(where: { $0.weather == .rainy || $0.weather == .snowy }) {
				return mergeAdjacentWindows(inferred)
			}
		}

		let hourly = weather.hourlyForecast.forecast
		let hourWindows = hourly.map {
			WeatherWindow(
				startDate: $0.date,
				endDate: $0.date.addingTimeInterval(3600),
				weather: WeatherType(from: $0)
			)
		}

		guard !hourWindows.isEmpty else {
			let current = weather.currentWeather
			return [WeatherWindow(startDate: current.date, endDate: current.date.addingTimeInterval(3600), weather: WeatherType(from: current))]
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

	private func inferWeather(from minute: MinuteWeather) -> WeatherType {
		let intensity = minute.precipitationIntensity.value
		let chance = minute.precipitationChance
		if intensity > 0.0 { return .rainy }
		if chance >= 0.6 { return .cloudy }
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
		var events: [Date: SunTimes] = [:]
		for day in weather.dailyForecast.forecast {
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
			WeatherWindow(startDate: startOfDay, endDate: startOfDay.addingTimeInterval(18_000), weather: .sunny),
			WeatherWindow(startDate: startOfDay.addingTimeInterval(18_000), endDate: startOfDay.addingTimeInterval(43_200), weather: .cloudy),
			WeatherWindow(startDate: startOfDay.addingTimeInterval(43_200), endDate: startOfDay.addingTimeInterval(64_800), weather: .rainy)
		]

		let sunrise = calendar.date(bySettingHour: 6, minute: 30, second: 0, of: startOfDay)!
		let sunset = calendar.date(bySettingHour: 18, minute: 30, second: 0, of: startOfDay)!
		let events = [startOfDay: SunTimes(sunrise: sunrise, sunset: sunset)]

		return WeatherReport(location: nil, locality: locality, currentWeather: .sunny, windows: windows, sunEvents: events)
	}

	// MARK: - Persistence
	private func persistToDisk(_ report: WeatherReport) {
		let snap = WeatherReportSnapshot(
			latitude: report.location?.coordinate.latitude,
			longitude: report.location?.coordinate.longitude,
			locality: report.locality,
			current: report.currentWeather.rawValue,
			windows: report.windows.map {
				WeatherWindowSnapshot(startDate: $0.startDate, endDate: $0.endDate, weather: $0.weather.rawValue)
			},
			sunEvents: report.sunEvents.map {
				SunEventSnapshot(day: $0.key, sunrise: $0.value.sunrise, sunset: $0.value.sunset)
			},
			timestamp: Date()
		)

		do {
			let data = try JSONEncoder().encode(snap)
			UserDefaults.standard.set(data, forKey: cacheKey)
		} catch {
			log.error("❌ Failed to persist weather snapshot: \(error.localizedDescription, privacy: .public)")
		}
	}

	@discardableResult
	private func restoreFromDisk() -> WeatherReport? {
		guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }

		do {
			let snap = try JSONDecoder().decode(WeatherReportSnapshot.self, from: data)
			let cal = TimeZoneManager.shared.calendar
			let sunEvents = Dictionary(uniqueKeysWithValues: (snap.sunEvents ?? []).map { s in
				(cal.startOfDay(for: s.day), SunTimes(sunrise: s.sunrise, sunset: s.sunset))
			})

			let loc: CLLocation? = {
				if let lat = snap.latitude, let lon = snap.longitude {
					return CLLocation(latitude: lat, longitude: lon)
				}
				return nil
			}()

			let report = WeatherReport(
				location: loc,
				locality: snap.locality,
				currentWeather: WeatherType(rawValue: snap.current) ?? .cloudy,
				windows: snap.windows.map {
					WeatherWindow(startDate: $0.startDate, endDate: $0.endDate, weather: WeatherType(rawValue: $0.weather) ?? .cloudy)
				},
				sunEvents: sunEvents
			)

			currentWeatherReport = report
			lastFetchAt = snap.timestamp
			if let lat = snap.latitude, let lon = snap.longitude {
				lastFetchedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
			}

			return report
		} catch {
			log.error("❌ Failed to restore weather snapshot: \(error.localizedDescription, privacy: .public)")
			return nil
		}
	}
}

// MARK: - WeatherType Conversion
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
