import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
	
    private let timeFormat = Date.FormatStyle()
        .hour(.twoDigits)
        .minute(.twoDigits)

    func subtitle(for task: Task) -> String {
        let time = task.date.formatted(timeFormat)
        return "\(task.category.title) · \(time) · 天气: \(task.weatherType.title)"
    }

    func badge(for task: Task) -> String {
        "⚡️\(task.energyReward)"
    }

    func forceRefresh(appModel: AppViewModel) async {
        let pending = appModel.todayTasks.filter { $0.status == .pending }
        let retained = pending.randomElement()
        await appModel.refreshTasks(retaining: retained)
    }
}
