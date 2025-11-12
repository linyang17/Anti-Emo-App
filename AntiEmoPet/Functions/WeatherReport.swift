import Foundation
import CoreLocation

struct WeatherWindow: Identifiable, Sendable, Hashable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let weather: WeatherType

    init(id: UUID = UUID(), startDate: Date, endDate: Date, weather: WeatherType) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.weather = weather
    }

    func contains(_ date: Date) -> Bool {
        (startDate...endDate).contains(date)
    }
}

struct WeatherReport: Sendable {
    let location: CLLocation?
    let locality: String?
    let currentWeather: WeatherType
    let windows: [WeatherWindow]

    init(location: CLLocation?, locality: String?, currentWeather: WeatherType, windows: [WeatherWindow]) {
        self.location = location
        self.locality = locality
        self.currentWeather = currentWeather
        self.windows = windows
    }

    func window(at date: Date) -> WeatherWindow? {
        windows.first { $0.contains(date) }
    }
}
