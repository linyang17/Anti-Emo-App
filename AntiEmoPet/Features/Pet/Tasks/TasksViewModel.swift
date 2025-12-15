import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
    @Published var isRefreshing = false


    func subtitle(for task: UserTask) -> String {
        return "\(task.category.localizedTitle)"
    }

    func badge(for task: UserTask) -> String {
        "⚡️ \(task.energyReward)"
    }

}
