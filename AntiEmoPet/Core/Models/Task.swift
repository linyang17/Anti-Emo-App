import Foundation
import SwiftData

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

enum TaskDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard

    var energyReward: Int {
        switch self {
        case .easy: return 5
        case .medium: return 10
        case .hard: return 15
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case completed
}

@Model
final class Task: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var weatherType: WeatherType
    var difficulty: TaskDifficulty
    var date: Date
    var status: TaskStatus

    init(
        id: UUID = UUID(),
        title: String,
        weatherType: WeatherType,
        difficulty: TaskDifficulty,
        date: Date,
        status: TaskStatus = .pending
    ) {
        self.id = id
        self.title = title
        self.weatherType = weatherType
        self.difficulty = difficulty
        self.date = date
        self.status = status
    }
}
