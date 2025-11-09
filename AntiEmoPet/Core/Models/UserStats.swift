import Foundation
import SwiftData

@Model
final class UserStats: Identifiable {
    @Attribute(.unique) var id: UUID
    var totalEnergy: Int
    var coins: Int
    var TotalDays: Int
    var lastActiveDate: Date
    var completedTasksCount: Int
    var nickname: String
    var region: String
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        totalEnergy: Int = 100,
        coins: Int = 10,
        streakDays: Int = 0,
        lastActiveDate: Date = .now,
        completedTasksCount: Int = 0,
        nickname: String = "",
        region: String = "",
        notificationsEnabled: Bool = false
    ) {
        self.id = id
        self.totalEnergy = totalEnergy
        self.coins = coins
        self.TotalDays = streakDays
        self.lastActiveDate = lastActiveDate
        self.completedTasksCount = completedTasksCount
        self.nickname = nickname
        self.region = region
        self.notificationsEnabled = notificationsEnabled
    }
}
