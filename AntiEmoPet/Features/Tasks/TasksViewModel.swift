import Foundation
import Combine

@MainActor
final class TasksViewModel: ObservableObject {
    func subtitle(for task: Task) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return "天气: \(task.weatherType.title) · 期限: \(formatter.string(from: task.date))"
    }

    func badge(for task: Task) -> String {
        switch task.difficulty {
        case .easy: return "EASY"
        case .medium: return "MED"
        case .hard: return "HARD"
        }
    }
}
