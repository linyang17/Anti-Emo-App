import Foundation

@MainActor
final class TaskGeneratorService {
    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func generateTasks(for date: Date, weather: WeatherType) -> [Task] {
        var templates = storage.fetchTemplates(for: weather)
        if templates.isEmpty {
            templates = WeatherType.allCases.flatMap { storage.fetchTemplates(for: $0) }
        }
        // TODO(中/EN): Inject personalization weights (circadian, streak) & dedupe history per PRD §3 once analytics ready.

        let count = min(max(templates.count, 3), 6)
        let picked = Array(templates.shuffled().prefix(count))

        let tasks = picked.map { template in
            Task(
                title: template.title,
                weatherType: template.weatherType,
                difficulty: template.difficulty,
                date: date
            )
        }
        storage.save(tasks: tasks)
        return tasks
    }
}
