import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    func streakDescription(for stats: UserStats) -> String {
        "你已经陪伴Lumio\(stats.TotalDays) 天"
    }
}
