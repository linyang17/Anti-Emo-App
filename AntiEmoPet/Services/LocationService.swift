import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
	@Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
	@Published private(set) var lastKnownLocation: CLLocation?
	@Published private(set) var lastKnownCity: String = ""
	@Published private(set) var weatherPermissionGranted: Bool = false

	private let manager = CLLocationManager()
	private let geocoder = CLGeocoder()

	override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
		manager.distanceFilter = 500
		manager.activityType = .other
		authorizationStatus = manager.authorizationStatus
	}

	func requestAuthorization() {
		manager.requestWhenInUseAuthorization()
	}

	/// 一次性定位，适合天气场景（省电）
	func requestLocationOnce() {
		// iOS 18+ 推荐一次性定位
		manager.requestLocation()
	}

	func startUpdating() { manager.startUpdatingLocation() }
	func stopUpdating()  { manager.stopUpdatingLocation()  }

	func updateWeatherPermission(granted: Bool) {
		weatherPermissionGranted = granted
	}

	private func reverseGeocodeIfNeeded(for location: CLLocation) {
		geocoder.cancelGeocode()
		geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
			guard let self else { return }
			if let placemark = placemarks?.first {
				let city = placemark.locality ?? placemark.administrativeArea ?? ""
				self.lastKnownCity = city
			}
		}
	}
}

extension LocationService: CLLocationManagerDelegate {
	nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		Task { @MainActor in
			self.authorizationStatus = manager.authorizationStatus
		}
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		// 保持沉默并使用缓存/默认值
		// print("Location error:", error.localizedDescription)
	}

	nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let latest = locations.last else { return }
		Task { @MainActor in
			self.lastKnownLocation = latest
			self.reverseGeocodeIfNeeded(for: latest)
		}
	}
}
