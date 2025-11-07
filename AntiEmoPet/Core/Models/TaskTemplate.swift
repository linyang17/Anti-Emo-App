import Foundation
import SwiftData

@Model
final class TaskTemplate: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var weatherType: WeatherType
    var difficulty: TaskDifficulty
    var isOutdoor: Bool

    init(
        id: UUID = UUID(),
        title: String,
        weatherType: WeatherType,
        difficulty: TaskDifficulty,
        isOutdoor: Bool
    ) {
        self.id = id
        self.title = title
        self.weatherType = weatherType
        self.difficulty = difficulty
        self.isOutdoor = isOutdoor
    }
}
