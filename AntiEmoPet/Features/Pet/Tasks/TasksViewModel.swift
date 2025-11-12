import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
    @Published var isRefreshing = false


    func subtitle(for task: UserTask) -> String {
        return "\(task.category.title)"
    }

    func badge(for task: UserTask) -> String {
        "⚡️ \(task.energyReward)"
    }

    func forceRefresh(appModel: AppViewModel) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let pending = appModel.todayTasks.filter { $0.status == .pending }
        let retained = pending.randomElement()
        await appModel.refreshTasks(retaining: retained)
    }
}
