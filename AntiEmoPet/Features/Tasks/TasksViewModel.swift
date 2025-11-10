import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
	
    private let dueFormat = Date.FormatStyle()
        .month(.twoDigits)
        .day(.twoDigits)

    func subtitle(for task: Task) -> String {
        let dueDate = task.date.formatted(dueFormat)
        return "天气: \(task.weatherType.title) · 期限: \(dueDate)"
    }

    func badge(for task: Task) -> String {
        switch task.difficulty {
        case .easy: return "EASY"
        case .medium: return "MED"
        case .hard: return "HARD"
        }
    }
}
