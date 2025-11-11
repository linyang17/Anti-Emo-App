import Foundation
internal import CoreLocation
import OSLog
import Combine

final class LocationService: NSObject, ObservableObject {
    
    private let manager = CLLocationManager()
    private let log = Logger(subsystem: "com.Lumio.pet", category: "LocationService")

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownCity: String?
    @Published var lastKnownLocation: CLLocation?
    @Published var weatherPermissionGranted: Bool = false

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func updateWeatherPermission(granted: Bool) {
        weatherPermissionGranted = granted
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            log.warning("Location permission denied or restricted")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastKnownLocation = location
        // Reverse geocode to city name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let error = error {
                self.log.error("Reverse geocode failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            if let city = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea {
                DispatchQueue.main.async {
                    self.lastKnownCity = city
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        log.error("Location update failed: \(error.localizedDescription, privacy: .public)")
    }
}
