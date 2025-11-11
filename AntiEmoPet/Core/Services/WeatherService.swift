import Foundation
internal import CoreLocation
import WeatherKit
import Combine
import OSLog

@MainActor
final class WeatherService: ObservableObject {
	private let log = Logger(subsystem: "com.Lumio.pet", category: "WeatherService")

	// MARK: - Published Observables
	@Published var currentWeatherReport: WeatherReport?
	@Published var isAuthorized: Bool = false

	private let locationManager = CLLocationManager()
	private let weatherService = WeatherKit.WeatherService.shared

	// MARK: - Initialization
	init() {
		Task { await checkLocationAuthorization() }
	}

	// MARK: - Location Authorization
	func checkLocationAuthorization() async -> Bool {
		let status = locationManager.authorizationStatus
		switch status {
		case .notDetermined:
			locationManager.requestWhenInUseAuthorization()
			try? await Task.sleep(nanoseconds: 500_000_000) // give iOS time to update status
			isAuthorized = locationManager.authorizationStatus == .authorizedWhenInUse ||
						   locationManager.authorizationStatus == .authorizedAlways
		case .authorizedWhenInUse, .authorizedAlways:
			isAuthorized = true
		default:
			isAuthorized = false
		}
		return isAuthorized
	}

	// MARK: - Fetch Weather
	func fetchWeather(for location: CLLocation?, locality: String?) async -> WeatherReport {
		guard let location else {
			return fallbackReport(locality: locality)
		}

		guard isAuthorized else {
			log.warning("⚠️ Weather fetch attempted before authorization.")
			return fallbackReport(locality: locality)
		}

		do {
			let weather = try await weatherService.weather(for: location)
			let current = WeatherType(from: weather.currentWeather)
			let windows = buildWindows(weather: weather)
			let report = WeatherReport(location: location, locality: locality, currentWeather: current, windows: windows)
			currentWeatherReport = report
			return report
		} catch {
			log.error("WeatherKit fetch failed: \(error.localizedDescription, privacy: .public)")
			let fallback = fallbackReport(locality: locality)
			currentWeatherReport = fallback
			return fallback
		}
	}

	// MARK: - Window Builders
	private func buildWindows(weather: Weather) -> [WeatherWindow] {
		// 1️⃣ 优先尝试分钟级天气（更精细）
		if let minuteForecast = weather.minuteForecast?.forecast, !minuteForecast.isEmpty {
			let inferredWindows = buildMinuteWindows(minuteForecast)
			// 若全部为晴朗（表示无降水信息），则回退到小时级
			let hasRain = inferredWindows.contains { $0.weather == .rainy || $0.weather == .snowy }
			if hasRain {
				return mergeAdjacentWindows(inferredWindows)
			}
		}

		// 2️⃣ 使用小时级天气（默认路径）
		let hourly = weather.hourlyForecast.forecast
		let hourWindows = hourly.map {
			WeatherWindow(
				startDate: $0.date,
				endDate: $0.date.addingTimeInterval(3600),
				weather: WeatherType(from: $0)
			)
		}

		// 3️⃣ 如果小时数据也没有内容，使用当前天气兜底
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
	
	// MARK: - 智能天气推断（分钟级）
	private func inferWeather(from minute: MinuteWeather) -> WeatherType {
		let intensity = minute.precipitationIntensity.value
		let chance = minute.precipitationChance // 这是 Double (0.0 ~ 1.0)

		// 有明确降水（中等或更强）
		if intensity > 0 {
			return .rainy
		}
		// 有轻度降水或较高降水概率
		else if chance > 0.3 && intensity > 0 {
			return .cloudy
		}
		// 无降水 → 晴
		else {
			return .sunny
		}
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

	// MARK: - Fallback
	private func fallbackReport(locality: String?) -> WeatherReport {
		let now = Date()
		let calendar = Calendar.current
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
		return WeatherReport(location: nil, locality: locality, currentWeather: .sunny, windows: windows)
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
