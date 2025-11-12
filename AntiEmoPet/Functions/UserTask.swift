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
}

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case outdoor
    case indoorDigital
    case indoorPhysical
    case social
    case petCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outdoor: return "户外行动"
        case .indoorDigital: return "室内电子"
        case .indoorPhysical: return "室内现实"
        case .social: return "社交互动"
        case .petCare: return "宠物互动"
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable {
    case pending
    case completed
}

@Model
final class UserTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var weatherType: WeatherType
    var difficulty: TaskDifficulty
    var category: TaskCategory
    var energyReward: Int = 0
    var date: Date
    var status: TaskStatus
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        weatherType: WeatherType,
        difficulty: TaskDifficulty,
        category: TaskCategory,
        energyReward: Int,
        date: Date,
        status: TaskStatus = .pending,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.weatherType = weatherType
        self.difficulty = difficulty
        self.category = category
        self.energyReward = energyReward
        self.date = date
        self.status = status
        self.completedAt = completedAt
    }
}
