import Foundation

@MainActor
final class TaskGeneratorService {
    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func generateTasks(for date: Date, weather: WeatherType, count: Int = 3) -> [Task] {
        let templates = storage.fetchAllTaskTemplates()
        guard !templates.isEmpty else { return [] }

        var prioritized = templates.filter { $0.weatherType == weather }
        if prioritized.count < count {
            let supplements = templates.filter { $0.weatherType != weather }
            prioritized.append(contentsOf: supplements)
        }

        var seenTitles = Set<String>()
        let uniqueTemplates = prioritized.filter { seenTitles.insert($0.title).inserted }.shuffled()
        let picked = uniqueTemplates.prefix(count)

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
