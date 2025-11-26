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
	func requestLocationOnce() async -> String {
        manager.requestLocation()
        // Safely unwrap the last known location before reverse geocoding
        if let location = lastKnownLocation {
            let resolvedCity = await reverseGeocodeIfNeeded(for: location)
            return resolvedCity
        } else {
            // No location yet; return current cached/known city (may be empty)
            return lastKnownCity
        }
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

			let city = placemark.locality ??
					   placemark.administrativeArea ??
					   placemark.name ??
					   placemark.inlandWater ??
					   placemark.ocean ??
					   ""
			
			await MainActor.run {
				self.lastKnownCity = city
				self.lastReverseAt = Date()
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
		guard let latest = locations.last else { return }

		lastKnownLocation = latest

		// Perform reverse geocoding asynchronously off the main actor.
		Task.detached(priority: .utility) { [weak self] in
			guard let self else { return }
			let city = await self.reverseGeocodeIfNeeded(for: latest)
			await MainActor.run {
				if !city.isEmpty {
					self.lastKnownCity = city
				} else {
					print("❌ Failed to resolve city, location: \(latest)")
				}
			}
		}
	}

	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		print("❌ Location failed:", error.localizedDescription)
		locationContinuation?.resume(returning: lastKnownCity)
		locationContinuation = nil
	}
	
}

