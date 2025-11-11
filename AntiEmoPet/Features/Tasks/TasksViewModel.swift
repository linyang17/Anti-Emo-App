import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
	
    private let timeFormat = Date.FormatStyle()
        .hour(.twoDigits(amPM: .omitted))
        .minute(.twoDigits)

    func subtitle(for task: UserTask) -> String {
        let time = task.date.formatted(timeFormat)
        return "\(task.category.title) · \(time) · 天气: \(task.weatherType.title)"
    }

    func badge(for task: UserTask) -> String {
        "⚡️\(task.energyReward)"
    }

    func forceRefresh(appModel: AppViewModel) async {
        let pending = appModel.todayTasks.filter { $0.status == .pending }
        let retained = pending.randomElement()
        await appModel.refreshTasks(retaining: retained)
    }
}
