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
            didInsert = try ensureSeed(for: Pet.self) { [Pet(name: "Sunny")] } || didInsert
            didInsert = try ensureSeed(for: UserStats.self) { [UserStats()] } || didInsert
            didInsert = try ensureItems() || didInsert
            didInsert = try ensureTaskTemplates() || didInsert
            if didInsert { saveContext(reason: "bootstrap seeds") }
        } catch {
            logger.error("Failed to bootstrap seeds: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchPet() -> Pet? {
        do {
            if try ensureSeed(for: Pet.self) { [Pet(name: "Sunny")] } {
                saveContext(reason: "ensure pet seed")
            }
            var descriptor = FetchDescriptor<Pet>()
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        } catch {
            logger.error("Failed to fetch pet: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func fetchStats() -> UserStats? {
        do {
            if try ensureSeed(for: UserStats.self) { [UserStats()] } {
                saveContext(reason: "ensure stats seed")
            }
            var descriptor = FetchDescriptor<UserStats>()
            descriptor.fetchLimit = 1
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

    @discardableResult
    private func ensureSeed<T: PersistentModel>(
        for _: T.Type,
        fetchDescriptor: FetchDescriptor<T> = FetchDescriptor<T>(),
        create: () -> [T]
    ) throws -> Bool {
        var descriptor = fetchDescriptor
        descriptor.fetchLimit = 1
        let existing = try context.fetch(descriptor)
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

    // MARK: - Inventory

    func fetchInventory() -> [InventoryEntry] {
        do {
            return try context.fetch(FetchDescriptor<InventoryEntry>())
        } catch {
            logger.error("Failed to fetch inventory: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func addToInventory(item: Item, quantity: Int = 1) {
        do {
            let predicate = #Predicate<InventoryEntry> { $0.sku == item.sku }
            let descriptor = FetchDescriptor<InventoryEntry>(predicate: predicate)
            let existing = try context.fetch(descriptor).first
            if let entry = existing {
                entry.quantity += quantity
            } else {
                context.insert(InventoryEntry(sku: item.sku, name: item.name, type: item.type, quantity: quantity))
            }
            saveContext(reason: "add to inventory")
        } catch {
            logger.error("Failed to add to inventory: \(error.localizedDescription, privacy: .public)")
        }
    }

    @discardableResult
    func consumeFromInventory(sku: String, quantity: Int = 1) -> Bool {
        do {
            let predicate = #Predicate<InventoryEntry> { $0.sku == sku }
            let descriptor = FetchDescriptor<InventoryEntry>(predicate: predicate)
            if let entry = try context.fetch(descriptor).first, entry.quantity >= quantity {
                entry.quantity -= quantity
                if entry.quantity == 0 {
                    context.delete(entry)
                }
                saveContext(reason: "consume inventory")
                return true
            }
            return false
        } catch {
            logger.error("Failed to consume inventory: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Mood Entries / Statistics

    func fetchMoodEntries(limit: Int? = nil) -> [MoodEntry] {
        do {
            var descriptor = FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\MoodEntry.date, order: .reverse)])
            if let limit { descriptor.fetchLimit = limit }
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch mood entries: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func ensureTodayMoodEntry(weather: WeatherType, mood: PetMood) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? .now
        let predicate = #Predicate<MoodEntry> { $0.date >= start && $0.date < end }
        let descriptor = FetchDescriptor<MoodEntry>(predicate: predicate)
        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty {
                let entry = MoodEntry(date: .now, weather: weather, mood: mood)
                context.insert(entry)
                saveContext(reason: "ensure today mood entry")
            }
        } catch {
            logger.error("Failed to ensure today mood entry: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum DefaultSeeds {
    fileprivate struct ItemSeed: Codable {
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

    fileprivate struct TaskTemplateSeed: Codable {
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

    private static func loadJSON<T: Decodable>(_ filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: "Static") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger(subsystem: "com.sunny.pet", category: "DefaultSeeds").error("Failed to decode \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static let fallbackItemSeeds: [ItemSeed] = [
        ItemSeed(sku: "snack.energy.bar", type: .snack, name: "能量棒", costEnergy: 15, moodBoost: 4, hungerBoost: 12),
        ItemSeed(sku: "snack.bubble.tea", type: .snack, name: "暖暖奶茶", costEnergy: 20, moodBoost: 6, hungerBoost: 10),
        ItemSeed(sku: "toy.pillow", type: .toy, name: "抱枕", costEnergy: 18, moodBoost: 8, hungerBoost: 0),
        ItemSeed(sku: "toy.ball", type: .toy, name: "发光球", costEnergy: 22, moodBoost: 10, hungerBoost: 0),
        ItemSeed(sku: "decor.fairy.lights", type: .decor, name: "氛围灯", costEnergy: 25, moodBoost: 12, hungerBoost: 0)
    ]

    private static let fallbackTaskTemplateSeeds: [TaskTemplateSeed] = [
        TaskTemplateSeed(title: "晒晒太阳 10 分钟", weatherType: .sunny, difficulty: .easy, isOutdoor: true),
        TaskTemplateSeed(title: "阳台瑜伽流", weatherType: .sunny, difficulty: .medium, isOutdoor: false),
        TaskTemplateSeed(title: "云下冥想", weatherType: .cloudy, difficulty: .easy, isOutdoor: false),
        TaskTemplateSeed(title: "阴天咖啡散步", weatherType: .cloudy, difficulty: .medium, isOutdoor: true),
        TaskTemplateSeed(title: "雨天热饮", weatherType: .rainy, difficulty: .medium, isOutdoor: false),
        TaskTemplateSeed(title: "雨声伴读", weatherType: .rainy, difficulty: .easy, isOutdoor: false),
        TaskTemplateSeed(title: "雪地慢走", weatherType: .snowy, difficulty: .medium, isOutdoor: true),
        TaskTemplateSeed(title: "暖灯伸展", weatherType: .snowy, difficulty: .easy, isOutdoor: false),
        TaskTemplateSeed(title: "风中伸展", weatherType: .windy, difficulty: .easy, isOutdoor: true),
        TaskTemplateSeed(title: "室内舞动 5 分钟", weatherType: .windy, difficulty: .medium, isOutdoor: false)
    ]

    static func makeItems() -> [Item] {
        let seeds: [ItemSeed] = loadJSON("items") ?? fallbackItemSeeds
        return seeds.map { $0.make() }
    }

    static func makeTaskTemplates() -> [TaskTemplate] {
        let seeds: [TaskTemplateSeed] = loadJSON("task_templates") ?? fallbackTaskTemplateSeeds
        return seeds.map { $0.make() }
    }
}
