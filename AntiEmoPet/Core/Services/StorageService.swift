import Foundation
import SwiftData
import OSLog

@MainActor
final class StorageService {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.sunny.pet", category: "StorageService")

    init(context: ModelContext) {
        self.context = context
    }

    func bootstrapIfNeeded() {
        do {
            var didInsert = false
            didInsert = try ensureSeed(for: Pet.self, create: { [Pet(name: "Sunny")] }) || didInsert
            didInsert = try ensureSeed(for: UserStats.self, create: { [UserStats()] }) || didInsert
            didInsert = try ensureItems() || didInsert
            didInsert = try ensureTaskTemplates() || didInsert
            if didInsert { saveContext(reason: "bootstrap seeds") }
        } catch {
            logger.error("Failed to bootstrap seeds: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchPet() -> Pet? {
        do {
            if try ensureSeed(for: Pet.self, create: { [Pet(name: "Sunny")] }) {
                saveContext(reason: "ensure pet seed")
            }
            let descriptor = FetchDescriptor<Pet>()
            return try context.fetch(descriptor).first
        } catch {
            logger.error("Failed to fetch pet: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func fetchStats() -> UserStats? {
        do {
            if try ensureSeed(for: UserStats.self, create: { [UserStats()] }) {
                saveContext(reason: "ensure stats seed")
            }
            let descriptor = FetchDescriptor<UserStats>()
            return try context.fetch(descriptor).first
        } catch {
            logger.error("Failed to fetch stats: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func fetchShopItems() -> [Item] {
        do {
            if try ensureItems() {
                saveContext(reason: "ensure item seeds")
            }
            let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\Item.costEnergy, order: .forward)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch shop items: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func fetchAllTaskTemplates() -> [TaskTemplate] {
        do {
            if try ensureTaskTemplates() {
                saveContext(reason: "ensure template seeds")
            }
            let descriptor = FetchDescriptor<TaskTemplate>(sortBy: [SortDescriptor(\TaskTemplate.title, order: .forward)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch all task templates: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func fetchTemplates(for weather: WeatherType) -> [TaskTemplate] {
        do {
            if try ensureTaskTemplates() {
                saveContext(reason: "ensure template seeds")
            }
            let predicate = #Predicate<TaskTemplate> { $0.weatherType == weather }
            let descriptor = FetchDescriptor<TaskTemplate>(predicate: predicate)
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch templates: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func fetchTasks(for date: Date) -> [Task] {
        do {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let predicate = #Predicate<Task> {
                $0.date >= start && $0.date < end
            }
            let descriptor = FetchDescriptor<Task>(
                predicate: predicate,
                sortBy: [SortDescriptor(\Task.date, order: .forward)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch tasks: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func save(tasks: [Task]) {
        guard !tasks.isEmpty else { return }
        tasks.forEach { context.insert($0) }
        saveContext(reason: "save tasks")
    }

    func persist() {
        saveContext(reason: "persist changes")
    }

    func fetchMoodEntries() -> [MoodEntry] {
        do {
            let descriptor = FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\MoodEntry.date, order: .reverse)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch mood entries: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func saveMoodEntry(_ entry: MoodEntry) {
        context.insert(entry)
        saveContext(reason: "save mood entry")
    }

    func fetchInventory() -> [InventoryEntry] {
        do {
            let descriptor = FetchDescriptor<InventoryEntry>(sortBy: [SortDescriptor(\InventoryEntry.sku, order: .forward)])
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch inventory: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func incrementInventory(forSKU sku: String) {
        do {
            let predicate = #Predicate<InventoryEntry> { $0.sku == sku }
            let descriptor = FetchDescriptor<InventoryEntry>(predicate: predicate)
            let existing = try context.fetch(descriptor).first
            if let entry = existing {
                entry.count += 1
            } else {
                let entry = InventoryEntry(sku: sku, count: 1)
                context.insert(entry)
            }
            saveContext(reason: "increment inventory")
        } catch {
            logger.error("Failed to increment inventory for sku \(sku, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func decrementInventory(forSKU sku: String) {
        do {
            let predicate = #Predicate<InventoryEntry> { $0.sku == sku }
            let descriptor = FetchDescriptor<InventoryEntry>(predicate: predicate)
            if let entry = try context.fetch(descriptor).first {
                entry.count = max(0, entry.count - 1)
                saveContext(reason: "decrement inventory")
            }
        } catch {
            logger.error("Failed to decrement inventory for sku \(sku, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    private func ensureSeed<T: PersistentModel>(
        for _: T.Type,
        fetchDescriptor: FetchDescriptor<T> = FetchDescriptor<T>(),
        create: () -> [T]
    ) throws -> Bool {
        let existing = try context.fetch(fetchDescriptor)
        guard existing.isEmpty else { return false }
        create().forEach { context.insert($0) }
        return true
    }

    @discardableResult
    private func ensureItems() throws -> Bool {
        let existing = try context.fetch(FetchDescriptor<Item>())
        let existingSKUs = Set(existing.map(\.sku))
        let missing = DefaultSeeds.makeItems().filter { !existingSKUs.contains($0.sku) }
        missing.forEach { context.insert($0) }
        return !missing.isEmpty
    }

    @discardableResult
    private func ensureTaskTemplates() throws -> Bool {
        let existing = try context.fetch(FetchDescriptor<TaskTemplate>())
        let existingTitles = Set(existing.map(\.title))
        let missing = DefaultSeeds.makeTaskTemplates().filter { !existingTitles.contains($0.title) }
        missing.forEach { context.insert($0) }
        return !missing.isEmpty
    }

    private func saveContext(reason: String) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context during \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum DefaultSeeds {
    fileprivate struct ItemSeed {
        let sku: String
        let type: ItemType
        let name: String
        let costEnergy: Int
        let moodBoost: Int
        let hungerBoost: Int

        func make() -> Item {
            Item(
                sku: sku,
                type: type,
                name: name,
                costEnergy: costEnergy,
                moodBoost: moodBoost,
                hungerBoost: hungerBoost
            )
        }
    }

    fileprivate struct TaskTemplateSeed {
        let title: String
        let weatherType: WeatherType
        let difficulty: TaskDifficulty
        let isOutdoor: Bool

        func make() -> TaskTemplate {
            TaskTemplate(
                title: title,
                weatherType: weatherType,
                difficulty: difficulty,
                isOutdoor: isOutdoor
            )
        }
    }

    private static let itemSeeds: [ItemSeed] = [
        ItemSeed(sku: "snack.energy.bar", type: .snack, name: "能量棒", costEnergy: 15, moodBoost: 4, hungerBoost: 12),
        ItemSeed(sku: "snack.bubble.tea", type: .snack, name: "暖暖奶茶", costEnergy: 20, moodBoost: 6, hungerBoost: 10),
        ItemSeed(sku: "toy.pillow", type: .toy, name: "围巾", costEnergy: 15, moodBoost: 8, hungerBoost: 0),
        ItemSeed(sku: "toy.ball", type: .toy, name: "发光球", costEnergy: 25, moodBoost: 12, hungerBoost: 0),
        ItemSeed(sku: "decor.fairy.lights", type: .decor, name: "氛围灯", costEnergy: 25, moodBoost: 12, hungerBoost: 0)
    ]

    private static let taskTemplateSeeds: [TaskTemplateSeed] = [
        TaskTemplateSeed(title: "晒太阳 10 分钟", weatherType: .sunny, difficulty: .easy, isOutdoor: true),
        TaskTemplateSeed(title: "做一组瑜伽", weatherType: .sunny, difficulty: .medium, isOutdoor: false),
        TaskTemplateSeed(title: "冥想3分钟", weatherType: .cloudy, difficulty: .easy, isOutdoor: false),
        TaskTemplateSeed(title: "买个水果散散步", weatherType: .cloudy, difficulty: .medium, isOutdoor: true),
        TaskTemplateSeed(title: "出门买一杯热饮", weatherType: .rainy, difficulty: .medium, isOutdoor: false),
        TaskTemplateSeed(title: "雨声伴读", weatherType: .rainy, difficulty: .easy, isOutdoor: false),
        TaskTemplateSeed(title: "室内打太极", weatherType: .snowy, difficulty: .medium, isOutdoor: true),
        TaskTemplateSeed(title: "室内伸展", weatherType: .snowy, difficulty: .easy, isOutdoor: false),
        TaskTemplateSeed(title: "室内运动", weatherType: .windy, difficulty: .easy, isOutdoor: true),
        TaskTemplateSeed(title: "跳操5分钟", weatherType: .windy, difficulty: .medium, isOutdoor: false)
    ]

    static func makeItems() -> [Item] {
        itemSeeds.map { $0.make() }
    }

    static func makeTaskTemplates() -> [TaskTemplate] {
        taskTemplateSeeds.map { $0.make() }
    }
}
