import Foundation
import CoreLocation
import MapKit
import Combine
import OSLog

struct RegionComponents: Codable, Equatable {
	let locality: String
	let administrativeArea: String
	let country: String
	
	var formatted: String {
		[locality, administrativeArea, country]
			.filter { !$0.isEmpty }
			.joined(separator: ", ")
	}
}

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
	@Published private(set) var lastRegionComponents: RegionComponents?
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
	private let logger = Logger(subsystem: "com.Lumio.pet", category: "LocationService")

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
			DispatchQueue.main.async { [weak self] in
				self?.manager.requestWhenInUseAuthorization()
			}
		default:
			break
		}
	}

	func updateWeatherPermission(granted: Bool) {
		weatherPermissionGranted = granted
	}

	// MARK: - Location Operations
	/// Request a one-time location update and await the resolved city.
	func requestLocationOnce(
		maxRetries: Int = 3,
		retryDelay: TimeInterval = 2.0,
		isOnboarding: Bool = false
	) async -> String {
        guard CLLocationManager.locationServicesEnabled() else {
            logger.error("Location services disabled.")
            return lastKnownCity
        }

        // Only proceed if already authorized; do not request here to avoid blocking UI.
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            logger.error("Location authorization missing or not determined. Call requestLocAuthorization() first and wait for locationManagerDidChangeAuthorization callback.")
            return lastKnownCity
        }

        if isOnboarding {
            isOnboardingPhase = true
            lastReverseAt = nil
            cityCache = nil
        } else {
            ensureCacheLoaded()
        }

        locationContinuation?.resume(returning: lastKnownCity)
        locationContinuation = nil

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            self.logger.debug("Location requested.")
            self.manager.requestLocation()
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

	/// Reverse geocodes a location into a city name, using cache when permitted.
	func reverseGeocodeIfNeeded(for location: CLLocation, ignoreCache: Bool = false) async -> String {
		if !ignoreCache {
			if let cached = cachedCityIfValid(for: location) {
				logger.debug("Using cached city: \(cached, privacy: .public)")
				return cached
			}
			
			if let lastAt = lastReverseAt,
			   Date().timeIntervalSince(lastAt) < minReverseInterval {
				logger.debug("Skipping reverse geocode (recent).")
				return lastKnownCity
			}
		} else {
			lastReverseAt = nil
		}
		
		do {
			let placemarks = try await geocoder.reverseGeocodeLocation(location)
			guard let placemark = placemarks.first else {
				logger.error("Reverse geocode returned no placemark.")
				return lastKnownCity
			}
			
			let components = RegionComponents(
				locality: placemark.locality ?? "",
				administrativeArea: placemark.administrativeArea ?? "",
				country: placemark.country ?? ""
			)
			let formatted = components.formatted.isEmpty ? (placemark.name ?? "") : components.formatted
			
			lastRegionComponents = components
			lastKnownCity = formatted
			lastReverseAt = Date()
			updateCityCache(city: formatted, for: location)
			logger.debug("Resolved city: \(formatted, privacy: .public)")
			return formatted
		} catch {
			logger.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
			return lastKnownCity
		}
	}
}

// MARK: - CLLocationManagerDelegate (Main Thread Safe)

extension LocationService: CLLocationManagerDelegate {
	
	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let latest = locations.last else {
			locationContinuation?.resume(returning: lastKnownCity)
			locationContinuation = nil
			return
		}

		lastKnownLocation = latest

		Task.detached(priority: .utility) { [weak self] in
			guard let self else { return }
			let ignoreCache = await self.isOnboardingPhase
			var resolvedCity = ""

			for attempt in 1...3 {
				resolvedCity = await self.reverseGeocodeIfNeeded(for: latest, ignoreCache: ignoreCache && attempt == 1)
				if !resolvedCity.isEmpty { break }
				if attempt < 3 {
					try? await Task.sleep(for: .seconds(2))
				}
			}

			await MainActor.run {
				if ignoreCache {
					self.isOnboardingPhase = false
				}

				if resolvedCity.isEmpty {
					self.logger.error("Failed to resolve city after retries. Location: \(latest)")
					resolvedCity = self.lastKnownCity
				} else {
					self.logger.debug("City resolved via delegate: \(resolvedCity, privacy: .public)")
				}

				self.locationContinuation?.resume(returning: resolvedCity)
				self.locationContinuation = nil
			}
		}
	}

	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		logger.error("Location failed: \(error.localizedDescription, privacy: .public)")
		locationContinuation?.resume(returning: lastKnownCity)
		locationContinuation = nil
	}
	
}
