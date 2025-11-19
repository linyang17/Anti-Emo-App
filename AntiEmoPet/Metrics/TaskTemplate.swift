import Foundation
import SwiftData

@Model
final class TaskTemplate: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var isOutdoor: Bool
    var category: TaskCategory
    var energyReward: Int = 0

    init(
        id: UUID = UUID(),
        title: String,
        isOutdoor: Bool,
        category: TaskCategory,
        energyReward: Int
    ) {
        self.id = id
        self.title = title
        self.isOutdoor = isOutdoor
        self.category = category
        self.energyReward = energyReward
    }
}
