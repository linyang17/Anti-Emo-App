import Foundation
import SwiftData

@MainActor
final class StorageService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func bootstrapIfNeeded() {
        if (try? context.fetch(FetchDescriptor<Pet>()))?.isEmpty ?? true {
            context.insert(Pet(name: "Sunny"))
        }

        if (try? context.fetch(FetchDescriptor<UserStats>()))?.isEmpty ?? true {
            context.insert(UserStats())
        }

        if (try? context.fetch(FetchDescriptor<Item>()))?.isEmpty ?? true {
            DefaultSeeds.items.forEach { context.insert($0) }
        }

        if (try? context.fetch(FetchDescriptor<TaskTemplate>()))?.isEmpty ?? true {
            DefaultSeeds.taskTemplates.forEach { context.insert($0) }
        }

        try? context.save()
    }

    func fetchPet() -> Pet? {
        try? context.fetch(FetchDescriptor<Pet>()).first
    }

    func fetchStats() -> UserStats? {
        try? context.fetch(FetchDescriptor<UserStats>()).first
    }

    func fetchShopItems() -> [Item] {
        (try? context.fetch(FetchDescriptor<Item>())) ?? []
    }

    func fetchTemplates(for weather: WeatherType) -> [TaskTemplate] {
        let predicate = #Predicate<TaskTemplate> { $0.weatherType == weather }
        return (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
    }

    func fetchTasks(for date: Date) -> [Task] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        let predicate = #Predicate<Task> {
            $0.date >= start && $0.date < end
        }
        let descriptor = FetchDescriptor<Task>(predicate: predicate)
        return (try? context.fetch(descriptor)) ?? []
    }

    func save(tasks: [Task]) {
        tasks.forEach { context.insert($0) }
        try? context.save()
    }

    func persist() {
        try? context.save()
    }
}

enum DefaultSeeds {
    static let taskTemplates: [TaskTemplate] = [
        TaskTemplate(title: "晒晒太阳 10 分钟", weatherType: .sunny, difficulty: .easy, isOutdoor: true),
        TaskTemplate(title: "阳台瑜伽流", weatherType: .sunny, difficulty: .medium, isOutdoor: false),
        TaskTemplate(title: "云下冥想", weatherType: .cloudy, difficulty: .easy, isOutdoor: false),
        TaskTemplate(title: "阴天咖啡散步", weatherType: .cloudy, difficulty: .medium, isOutdoor: true),
        TaskTemplate(title: "雨天热饮", weatherType: .rainy, difficulty: .medium, isOutdoor: false),
        TaskTemplate(title: "雨声伴读", weatherType: .rainy, difficulty: .easy, isOutdoor: false),
        TaskTemplate(title: "雪地慢走", weatherType: .snowy, difficulty: .medium, isOutdoor: true),
        TaskTemplate(title: "暖灯伸展", weatherType: .snowy, difficulty: .easy, isOutdoor: false),
        TaskTemplate(title: "风中伸展", weatherType: .windy, difficulty: .easy, isOutdoor: true),
        TaskTemplate(title: "室内舞动 5 分钟", weatherType: .windy, difficulty: .medium, isOutdoor: false)
    ]

    static let items: [Item] = [
        Item(sku: "snack.energy.bar", type: .snack, name: "能量棒", costEnergy: 15, moodBoost: 4, hungerBoost: 12),
        Item(sku: "snack.bubble.tea", type: .snack, name: "暖暖奶茶", costEnergy: 20, moodBoost: 6, hungerBoost: 10),
        Item(sku: "toy.pillow", type: .toy, name: "抱枕", costEnergy: 18, moodBoost: 8, hungerBoost: 0),
        Item(sku: "toy.ball", type: .toy, name: "发光球", costEnergy: 22, moodBoost: 10, hungerBoost: 0),
        Item(sku: "decor.fairy.lights", type: .decor, name: "氛围灯", costEnergy: 25, moodBoost: 12, hungerBoost: 0)
    ]
}
