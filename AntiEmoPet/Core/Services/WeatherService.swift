import Foundation

struct WeatherService {
    func fetchWeather() -> WeatherType {
        WeatherType.allCases.randomElement() ?? .sunny
    }
}
