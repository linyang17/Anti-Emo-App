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
    let currentTemperature: Double?
    let windows: [WeatherWindow]
    let sunEvents: [Date: SunTimes]

    init(
        location: CLLocation?,
        locality: String?,
        currentWeather: WeatherType,
        currentTemperature: Double?,
        windows: [WeatherWindow],
        sunEvents: [Date: SunTimes]
    ) {
        self.location = location
        self.locality = locality
        self.currentWeather = currentWeather
        self.currentTemperature = currentTemperature
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


func dayLengthMinutes(for date: Date, sunEvents: [Date: SunTimes]?) -> Int {
	let calendar = TimeZoneManager.shared.calendar
	let day = calendar.startOfDay(for: date)
	guard let sun = sunEvents?[day] else {
		return 0
	}

	var sunset = sun.sunset
	if sunset < sun.sunrise {
		sunset = calendar.date(byAdding: .day, value: 1, to: sunset) ?? sunset
	}

	let duration = sunset.timeIntervalSince(sun.sunrise)
	return Int(duration / 60)
}
