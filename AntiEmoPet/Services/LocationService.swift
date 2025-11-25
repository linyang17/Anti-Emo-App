import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Codable Cache Record

private struct CityCacheRecord: Codable {
	let latitude: Double
	let longitude: Double
	let city: String
	let timestamp: Date
}

// MARK: - Location Service

@MainActor
final class LocationService: NSObject, ObservableObject {

	// MARK: Published State

	@Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
	@Published private(set) var lastKnownLocation: CLLocation?
	@Published private(set) var lastKnownCity: String = ""
	@Published private(set) var weatherPermissionGranted = false

	// MARK: Private Properties

	private let manager = CLLocationManager()
	private let geocoder = CLGeocoder()

	// Cache
	private let cacheRadius: CLLocationDistance = 20_000      // 20 km
	private let minReverseInterval: TimeInterval = 60 * 60 * 3 // 3 hours
	private var cityCache: (coord: CLLocationCoordinate2D, city: String, timestamp: Date)?
	private var lastReverseAt: Date?
	private let cityCacheKey = "LocationService.cityCache"
	private var locationContinuation: CheckedContinuation<String, Never>?
	private var isOnboardingPhase: Bool = false

	// MARK: - Initialization

	override init() {
		super.init()
		configureManager()
	}
	
	/// Load city cache from disk (called when needed, not during onboarding)
	private func ensureCacheLoaded() {
		guard cityCache == nil else { return }
		loadCityCacheFromDisk()
	}

	private func configureManager() {
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
		manager.distanceFilter = 1_000
		manager.activityType = .other
		authorizationStatus = manager.authorizationStatus
	}

	// MARK: - Permissions

	func requestLocAuthorization() {
		switch authorizationStatus {
		case .notDetermined:
			manager.requestWhenInUseAuthorization()
		default:
			break
		}
	}

	func updateWeatherPermission(granted: Bool) {
		weatherPermissionGranted = granted
	}

	// MARK: - Location Operations

	/// Request location once and wait for city resolution
	/// - Parameter maxRetries: Maximum number of retries for geocoding (default: 5)
	/// - Parameter retryDelay: Delay between retries in seconds (default: 2.0)
	/// - Parameter isOnboarding: Whether this is called during onboarding phase (default: false)
	/// - Returns: Resolved city name, or empty string if all retries fail
	func requestLocationOnce(maxRetries: Int = 5, retryDelay: TimeInterval = 2.0, isOnboarding: Bool = false) async -> String {
		guard CLLocationManager.locationServicesEnabled() else {
			print("⚠️ Location services disabled.")
			return lastKnownCity
		}

		// Check authorization status first
		guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
			print("⚠️ Location authorization not granted: \(authorizationStatus.rawValue)")
			return lastKnownCity
		}

		if isOnboarding {
			isOnboardingPhase = true
			lastReverseAt = nil // force fresh geocode
		} else {
			ensureCacheLoaded()
		}

		// 防止上次 continuation 未释放
		locationContinuation?.resume(returning: lastKnownCity)
		locationContinuation = nil

		// Request location and wait for result
		let city = await withCheckedContinuation { continuation in
			self.locationContinuation = continuation
			manager.requestLocation()
			print("requestLocation() called.")
		}
		
		// If city is empty and we have a location, retry geocoding
		if city.isEmpty, let location = lastKnownLocation {
			print("⚠️ City is empty, retrying geocoding...")
			for attempt in 1...maxRetries {
				let resolvedCity = await reverseGeocodeIfNeeded(for: location, ignoreCache: isOnboarding)
				if !resolvedCity.isEmpty {
					print("✅ City resolved on retry \(attempt): \(resolvedCity)")
					return resolvedCity
				}
				if attempt < maxRetries {
					print("⚠️ Retry \(attempt) failed, waiting \(retryDelay)s...")
					try? await Task.sleep(for: .seconds(retryDelay))
				}
			}
			print("❌ Failed to resolve city after \(maxRetries) retries")
		}
		
		if isOnboarding {
			isOnboardingPhase = false
		}
		
		return city.isEmpty ? lastKnownCity : city
	}

	func startUpdating() {
		manager.startUpdatingLocation()
	}

	func stopUpdating() {
		manager.stopUpdatingLocation()
	}

	// MARK: - Cache Helpers

	private func cachedCityIfValid(for location: CLLocation) -> String? {
		guard let cityCache else { return nil }
		let cachedLoc = CLLocation(latitude: cityCache.coord.latitude, longitude: cityCache.coord.longitude)
		guard location.distance(from: cachedLoc) <= cacheRadius else { return nil }
		return cityCache.city
	}

	private func updateCityCache(city: String, for location: CLLocation) {
		cityCache = (location.coordinate, city, Date())
		saveCityCacheToDisk()
	}

	private func saveCityCacheToDisk() {
		guard let cityCache else { return }
		let record = CityCacheRecord(
			latitude: cityCache.coord.latitude,
			longitude: cityCache.coord.longitude,
			city: cityCache.city,
			timestamp: cityCache.timestamp
		)
		if let data = try? JSONEncoder().encode(record) {
			UserDefaults.standard.set(data, forKey: cityCacheKey)
		}
	}

	private func loadCityCacheFromDisk() {
		guard
			let data = UserDefaults.standard.data(forKey: cityCacheKey),
			let record = try? JSONDecoder().decode(CityCacheRecord.self, from: data)
		else { return }

		cityCache = (
			coord: CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude),
			city: record.city,
			timestamp: record.timestamp
		)
		lastKnownCity = record.city
	}

	// MARK: - Reverse Geocoding

	/// Reverse geocodes a location into a city name, using cache when possible.
	/// - Note: In onboarding phase, cache is ignored to ensure fresh resolution
	func reverseGeocodeIfNeeded(for location: CLLocation, ignoreCache: Bool = false) async -> String {
		// If ignoring cache (e.g., during onboarding), skip cache check
		if !ignoreCache {
			if let cached = cachedCityIfValid(for: location) {
				print("Using cached city:", cached)
				return cached
			}

			if let lastAt = lastReverseAt,
			   Date().timeIntervalSince(lastAt) < minReverseInterval {
				print("Skipping reverse geocode (too recent).")
				return lastKnownCity
			}
		} else {
			// Force fresh geocoding during onboarding
			lastReverseAt = nil
		}

		do {
			let placemarks = try await geocoder.reverseGeocodeLocation(location)
			guard let placemark = placemarks.first else {
				print("⚠️ No placemarks found")
				return lastKnownCity
			}

			let city = placemark.locality ?? placemark.administrativeArea ?? ""
			if !city.isEmpty {
				updateCityCache(city: city, for: location)
				lastReverseAt = Date()
				lastKnownCity = city
				print("✅ Updated city:", city)
			} else {
				print("⚠️ Placemark found but city is empty. Locality: \(placemark.locality ?? "nil"), AdministrativeArea: \(placemark.administrativeArea ?? "nil")")
			}
			return city
		} catch {
			print("❌ Reverse geocode failed:", error.localizedDescription)
			return lastKnownCity
		}
	}
}

// MARK: - CLLocationManagerDelegate (Main Thread Safe)

extension LocationService: CLLocationManagerDelegate {
	
	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
			// This callback is always invoked on the main thread by CoreLocation.
		authorizationStatus = manager.authorizationStatus
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		print("📍 didUpdateLocations triggered:", locations.count)
		guard let latest = locations.last else {
			print("⚠️ No valid location in array.")
			locationContinuation?.resume(returning: lastKnownCity)
			locationContinuation = nil
			return
		}

		lastKnownLocation = latest

		Task.detached { [weak self] in
			guard let self else { return }

			let ignoreCache = true
			
			var city: String = ""
			let maxRetries = 3
			for attempt in 1...maxRetries {
				city = await self.reverseGeocodeIfNeeded(for: latest, ignoreCache: ignoreCache && attempt == 1)
				if !city.isEmpty {
					print("✅ City resolved (attempt \(attempt)): \(city)")
					break
				}
				if attempt < maxRetries {
					print("⚠️ Attempt \(attempt) failed, retrying in 2s...")
					try? await Task.sleep(for: .seconds(2))
				}
			}

			await MainActor.run {
				if !city.isEmpty {
					self.lastKnownCity = city
					print("✅ Final city set:", city)
				} else {
					print("❌ Failed to resolve city after \(maxRetries) retries")
					print("   Location: \(latest)")
				}

				self.locationContinuation?.resume(returning: city.isEmpty ? self.lastKnownCity : city)
				self.locationContinuation = nil
			}
		}
	}

	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		print("❌ Location failed:", error.localizedDescription)
		locationContinuation?.resume(returning: lastKnownCity)
		locationContinuation = nil
	}
	
}
