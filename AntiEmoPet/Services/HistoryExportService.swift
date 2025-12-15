import Foundation

struct TaskHistoryRecord: Codable, Sendable {
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
        let relatedDayLength: Int
}

struct MoodHistoryRecord: Codable, Sendable {
        let id: UUID
        let date: Date
        let value: Int
        let source: String
        let delta: Int?
        let relatedTaskCategory: String?
        let relatedWeather: String?
        let relatedDayLength: Int
}

struct EnergyEventRecord: Codable, Sendable {
        let id: UUID
        let date: Date
        let delta: Int
        let relatedTaskId: UUID?
}

struct InventoryRecord: Codable, Sendable {
        let sku: String
        let quantity: Int
}

struct PetSnapshot: Codable, Sendable {
        let bondingScore: Int
        let level: Int
        let xp: Int
}

struct StatsSnapshot: Codable, Sendable {
        let totalEnergy: Int
}

struct TaskHistoryExport: Codable, Sendable {
        let exportedAt: Date
        let rangeStart: Date
        let rangeEnd: Date
        let tasks: [TaskHistoryRecord]
        let moods: [MoodHistoryRecord]
        let energyEvents: [EnergyEventRecord]
        let inventory: [InventoryRecord]?
        let pet: PetSnapshot?
        let stats: StatsSnapshot?
}

struct HistoryExportService {
        private let formatter: ISO8601DateFormatter = {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
        }()

        private lazy var encoder: JSONEncoder = {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .custom { [formatter] date, enc in
                        var container = enc.singleValueContainer()
                        try container.encode(formatter.string(from: date))
                }
                return encoder
        }()

        private lazy var decoder: JSONDecoder = {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { [formatter] dec -> Date in
                        let container = try dec.singleValueContainer()
                        let string = try container.decode(String.self)
                        return formatter.date(from: string) ?? Date()
                }
                return decoder
        }()

        mutating func export(
                tasks: [UserTask],
                moods: [MoodEntry],
                energyEvents: [EnergyEvent],
                inventory: [InventoryEntry],
                pet: Pet?,
                stats: UserStats?,
                range: ClosedRange<Date>
        ) throws -> URL {
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
                                isOnboarding: task.isOnboarding,
                                relatedDayLength: task.relatedDayLength
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
                                relatedWeather: mood.relatedWeather,
								relatedDayLength: mood.relatedDayLength
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

                let inventoryRecords = inventory.map { entry in
                        InventoryRecord(sku: entry.sku, quantity: entry.quantity)
                }

                let petSnapshot = pet.map { pet in
                        PetSnapshot(
                                bondingScore: pet.bondingScore,
                                level: pet.level,
                                xp: pet.xp
                        )
                }

                let statsSnapshot = stats.map { StatsSnapshot(totalEnergy: $0.totalEnergy) }

                let exportedAt = Date()
                let rangeStart = tasks.map(\.date).min() ?? exportedAt
                let rangeEnd = tasks.map(\.date).max() ?? exportedAt

                let payload = TaskHistoryExport(
                        exportedAt: exportedAt,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        tasks: taskRecords,
                        moods: moodRecords,
                        energyEvents: energyRecords,
                        inventory: inventoryRecords,
                        pet: petSnapshot,
                        stats: statsSnapshot
                )

                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate]
                let filename = "lumio_history_\(formatter.string(from: range.lowerBound))_to_\(formatter.string(from: range.upperBound)).lumiohistory"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                let data = try encoder.encode(payload)
                try data.write(to: url, options: .atomic)
                return url
        }

	mutating func importHistory(from url: URL) throws -> TaskHistoryExport {
                let data = try Data(contentsOf: url)
                return try decoder.decode(TaskHistoryExport.self, from: data)
        }
}
