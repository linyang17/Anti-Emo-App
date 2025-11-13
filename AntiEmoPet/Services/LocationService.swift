import Foundation
import CoreLocation
import MapKit
import Combine

private struct CityCacheRecord: Codable {
	let latitude: Double
	let longitude: Double
	let city: String
	let timestamp: Date
}

@MainActor
final class LocationService: NSObject, ObservableObject {

	@Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
	@Published private(set) var lastKnownLocation: CLLocation?
	@Published private(set) var lastKnownCity: String = ""
	@Published private(set) var weatherPermissionGranted: Bool = false

	private let manager = CLLocationManager()

	// MARK: - Reverse Geocode Cache
	// 缓存范围扩大：半径 20 公里，减少频繁反查
	private let cacheRadius: CLLocationDistance = 20000
	private var cityCache: (coord: CLLocationCoordinate2D, city: String, timestamp: Date)?
	private var lastReverseAt: Date?
	private let minReverseInterval: TimeInterval = 60*60*3 // 3小时内不重复反查
	private let cityCacheDefaultsKey = "LocationService.cityCache"

	// MARK: - Init
		override init() {
			super.init()
			manager.delegate = self
			// 一次性定位 + 低精度 + 较大距离过滤
			manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
			manager.distanceFilter = 1000
			manager.activityType = .other
			authorizationStatus = manager.authorizationStatus
			loadCityCacheFromDisk()
		}

	// MARK: - Permissions
	func requestLocAuthorization() {
		manager.requestWhenInUseAuthorization()
	}

	func updateWeatherPermission(granted: Bool) {
		weatherPermissionGranted = granted
	}

	// MARK: - One-shot Location
	func requestLocationOnce() {
		manager.requestLocation()
	}
	
	/// 如有持续跟踪需求，再使用以下两个
	func startUpdating() { manager.startUpdatingLocation() }
	func stopUpdating()  { manager.stopUpdatingLocation()  }

	// MARK: - Cache Helpers
	private func cachedCityIfValid(for location: CLLocation) -> String? {
		guard let cache = cityCache else { return nil }
		let cachedLoc = CLLocation(latitude: cache.coord.latitude, longitude: cache.coord.longitude)
		if location.distance(from: cachedLoc) <= cacheRadius {
			return cache.city
		}
		return nil
	}

		private func updateCityCache(city: String, for location: CLLocation) {
			cityCache = (coord: location.coordinate, city: city, timestamp: Date())
			saveCityCacheToDisk()
		}

		private func saveCityCacheToDisk() {
			guard let cache = cityCache else { return }
			let record = CityCacheRecord(latitude: cache.coord.latitude,
										 longitude: cache.coord.longitude,
										 city: cache.city,
										 timestamp: cache.timestamp)
			do {
				let data = try JSONEncoder().encode(record)
				UserDefaults.standard.set(data, forKey: cityCacheDefaultsKey)
			} catch {
				// ignore
			}
		}

		private func loadCityCacheFromDisk() {
			guard let data = UserDefaults.standard.data(forKey: cityCacheDefaultsKey) else { return }
			do {
				let record = try JSONDecoder().decode(CityCacheRecord.self, from: data)
				let coord = CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
				cityCache = (coord: coord, city: record.city, timestamp: record.timestamp)
				self.lastKnownCity = record.city
			} catch {
				// ignore
			}
		}

	// MARK: - Reverse Geocoding (iOS 26+ with fallback)
	/// 将 CLLocation 解析为城市名/行政区名。
	/// - iOS 26+: 使用 MKReverseGeocodingRequest（新 API）
	/// - iOS 18–25: 使用 CLGeocoder.async 版本
		func reverseGeocodeIfNeeded(for location: CLLocation) async -> String {
			if let cached = cachedCityIfValid(for: location) {
				return cached
			}
			if let lastAt = lastReverseAt, Date().timeIntervalSince(lastAt) < minReverseInterval {
				return lastKnownCity
			}
			/// if #available(iOS 26, *)  用新的API
			let geocoder = CLGeocoder()
			do {
				let placemarks = try await geocoder.reverseGeocodeLocation(location)
				if let placemark = placemarks.first {
					let city = placemark.locality ?? placemark.administrativeArea ?? ""
					if !city.isEmpty {
						updateCityCache(city: city, for: location)
						self.lastReverseAt = Date()
						self.lastKnownCity = city
					}
					return city
				}
			} catch { }
			return ""
		}
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

	nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		Task { @MainActor in
			self.authorizationStatus = manager.authorizationStatus
		}
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		// 失败时用上次缓存
		// print("Location error:", error.localizedDescription)
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let latest = locations.last else { return }

		Task { @MainActor in
			self.lastKnownLocation = latest
		}

		Task {
			let city = await self.reverseGeocodeIfNeeded(for: latest)
			await MainActor.run {
				self.lastKnownCity = city
			}
		}
	}
}
