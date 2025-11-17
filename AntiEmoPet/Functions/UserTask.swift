import Foundation
import SwiftData

enum TaskDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard
}

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case outdoor
    case indoorDigital
    case indoorActivity
	case physical
    case socials
    case petCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outdoor: return "Outdoor Activities"
        case .indoorDigital: return "Digital"
        case .indoorActivity: return "Indoor Activities"
        case .socials: return "Social Interactions"
        case .petCare: return "Pet Care"
		case .physical: return "Physical exercises"
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
