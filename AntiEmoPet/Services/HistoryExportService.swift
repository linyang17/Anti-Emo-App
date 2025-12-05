import Foundation

struct TaskHistoryRecord: Codable {
    let id: UUID
    let title: String
    let category: String
    let status: String
    let weather: String
    let energyReward: Int
    let date: Date
    let completedAt: Date?
    let isArchived: Bool
    let isOnboarding: Bool
}

struct MoodHistoryRecord: Codable {
    let id: UUID
    let date: Date
    let value: Int
    let source: String
    let delta: Int?
    let relatedTaskCategory: String?
    let relatedWeather: String?
}

struct EnergyEventRecord: Codable {
    let id: UUID
    let date: Date
    let delta: Int
    let relatedTaskId: UUID?
}

struct TaskHistoryExport: Codable {
    let exportedAt: Date
    let rangeStart: Date
    let rangeEnd: Date
    let tasks: [TaskHistoryRecord]
    let moods: [MoodHistoryRecord]
    let energyEvents: [EnergyEventRecord]
}

struct HistoryExportService {
    func export(tasks: [UserTask], moods: [MoodEntry], energyEvents: [EnergyEvent], range: ClosedRange<Date>) throws -> URL {
        let taskRecords = tasks.map { task in
            TaskHistoryRecord(
                id: task.id,
                title: task.title,
                category: task.category.rawValue,
                status: task.status.rawValue,
                weather: task.weatherType.rawValue,
                energyReward: task.energyReward,
                date: task.date,
                completedAt: task.completedAt,
                isArchived: task.isArchived,
                isOnboarding: task.isOnboarding
            )
        }

        let moodRecords = moods.map { mood in
            MoodHistoryRecord(
                id: mood.id,
                date: mood.date,
                value: mood.value,
                source: mood.source,
                delta: mood.delta,
                relatedTaskCategory: mood.relatedTaskCategory,
                relatedWeather: mood.relatedWeather
            )
        }

        let energyRecords = energyEvents.map { event in
            EnergyEventRecord(
                id: event.id,
                date: event.date,
                delta: event.delta,
                relatedTaskId: event.relatedTaskId
            )
        }

        let snapshot = TaskHistoryExport(
            exportedAt: Date(),
            rangeStart: range.lowerBound,
            rangeEnd: range.upperBound,
            tasks: taskRecords,
            moods: moodRecords,
            energyEvents: energyRecords
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let filename = "lumio_history_\(formatter.string(from: range.lowerBound))_to_\(formatter.string(from: range.upperBound)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}
