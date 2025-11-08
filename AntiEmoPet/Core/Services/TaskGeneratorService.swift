import Foundation

@MainActor
final class TaskGeneratorService {
    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func generateTasks(for date: Date, weather: WeatherType) -> [Task] {
        // Prefer templates for current weather; supplement from other weathers to ensure 3 tasks.
        var templates = storage.fetchTemplates(for: weather)
        if templates.count < 3 {
            let fallback = WeatherType.allCases
                .filter { $0 != weather }
                .flatMap { storage.fetchTemplates(for: $0) }
            templates.append(contentsOf: fallback)
        }

        let picked = Array(templates.shuffled().prefix(3))

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
