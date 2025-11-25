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

struct SunTimes: Sendable, Hashable {
    let sunrise: Date
    let sunset: Date
}


struct WeatherReport: Sendable {
    let location: CLLocation?
    let locality: String?
    let currentWeather: WeatherType
    let windows: [WeatherWindow]
    let sunEvents: [Date: SunTimes]

    init(location: CLLocation?, locality: String?, currentWeather: WeatherType, windows: [WeatherWindow], sunEvents: [Date: SunTimes]) {
        self.location = location
        self.locality = locality
        self.currentWeather = currentWeather
        self.windows = windows
        self.sunEvents = sunEvents
    }

    func window(at date: Date) -> WeatherWindow? {
        windows.first { $0.contains(date) }
    }

    func sunTimes(for date: Date, calendar: Calendar) -> SunTimes? {
        let day = calendar.startOfDay(for: date)
        return sunEvents[day]
    }
}


