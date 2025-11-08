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

        // Ensure we can build at least 3 tasks by supplementing from other weather templates if needed
        if templates.count < 3 {
            let supplement = WeatherType.allCases
                .filter { $0 != weather }
                .flatMap { storage.fetchTemplates(for: $0) }
            templates.append(contentsOf: supplement)
        }

        let targetCount = 3
        var picked: [TaskTemplate] = []
        if templates.isEmpty {
            picked = []
        } else if templates.count >= targetCount {
            picked = Array(templates.shuffled().prefix(targetCount))
        } else {
            // Cycle through templates to reach target count
            var idx = 0
            while picked.count < targetCount {
                picked.append(templates[idx % templates.count])
                idx += 1
            }
        }

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
