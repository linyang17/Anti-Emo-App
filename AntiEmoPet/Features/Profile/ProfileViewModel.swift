import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    func streakDescription(for stats: UserStats) -> String {
        "连续打卡 \(stats.streakDays) 天"
    }
}
