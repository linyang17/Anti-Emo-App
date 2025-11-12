import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {


    func subtitle(for task: UserTask) -> String {
        return "\(task.category.title)"
    }

    func badge(for task: UserTask) -> String {
        "⚡️ \(task.energyReward)"
    }

    func forceRefresh(appModel: AppViewModel) async {
        let pending = appModel.todayTasks.filter { $0.status == .pending }
        let retained = pending.randomElement()
        await appModel.refreshTasks(retaining: retained)
    }
}
