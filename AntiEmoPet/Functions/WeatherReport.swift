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

enum WeatherType: String, Codable, CaseIterable, Identifiable {
	case sunny, cloudy, rainy, snowy, windy

	var id: String { rawValue }

	var icon: String {
		switch self {
		case .sunny: return "sun.max"
		case .cloudy: return "cloud"
		case .rainy: return "cloud.rain"
		case .snowy: return "snow"
		case .windy: return "wind"
		}
	}

	var title: String {
		switch self {
		case .sunny: return "晴"
		case .cloudy: return "多云"
		case .rainy: return "雨"
		case .snowy: return "雪"
		case .windy: return "风"
		}
	}
}
