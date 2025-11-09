import Foundation
import SwiftUI
import SwiftData
import Combine

struct EnergyHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var totalEnergy: Int
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var todayTasks: [Task] = []
    @Published var pet: Pet?
    @Published var userStats: UserStats?
    @Published var shopItems: [Item] = []
    @Published var weather: WeatherType = .sunny
    @Published var chatMessages: [ChatMessage] = []
    @Published var isLoading = true
    @Published var showOnboarding = false
    @Published var moodEntries: [MoodEntry] = []
    @Published var energyHistory: [EnergyHistoryEntry] = []
    @Published var inventory: [InventoryEntry] = []

    private let storage: StorageService
    private let taskGenerator: TaskGeneratorService
    private let rewardEngine = RewardEngine()
    private let petEngine = PetEngine()
    private let notificationService = NotificationService()
    private let weatherService = WeatherService()
    private let chatService = ChatService()
    private let analytics = AnalyticsService()

    init(modelContext: ModelContext) {
        storage = StorageService(context: modelContext)
        taskGenerator = TaskGeneratorService(storage: storage)
    }

    var totalEnergy: Int {
        userStats?.totalEnergy ?? 0
    }

    var allTasks: [Task] {
        // MVP 阶段：全部任务等于今日任务列表
        // 未来如加入历史/模板任务库，只需在此改为从 StorageService / TaskGenerator 获取
        todayTasks
    }

    func load() {
        storage.bootstrapIfNeeded()
        weather = weatherService.fetchWeather()
        pet = storage.fetchPet()
        userStats = storage.fetchStats()

        // Ensure initial defaults per MVP PRD
        if let stats = userStats, stats.totalEnergy <= 0 {
            stats.totalEnergy = 50
        }

        // Load stored energy history (for daily totalEnergy snapshots)
        if let data = UserDefaults.standard.data(forKey: "energyHistory"),
           let decoded = try? JSONDecoder().decode([EnergyHistoryEntry].self, from: data) {
            energyHistory = decoded
        } else {
            // Initialize today's snapshot with current energy
            logTodayEnergySnapshot()
        }

        if let pet = pet {
            // Ensure reasonable initial hunger baseline at least 50
            if pet.hunger < 50 { pet.hunger = 50 }
            // XP baseline should start at 0 if negative
            if pet.xp < 0 { pet.xp = 0 }
        }

        shopItems = storage.fetchShopItems()

        moodEntries = storage.fetchMoodEntries()
        if moodEntries.isEmpty {
            addMoodEntry(value: 50) // 心情一般 baseline 50/100
        }
        inventory = storage.fetchInventory()

        todayTasks = storage.fetchTasks(for: .now)

        if todayTasks.isEmpty {
            todayTasks = taskGenerator.generateTasks(for: .now, weather: weather)
        }

        ensureInitialTasks(minimum: 3)

        showOnboarding = (userStats?.nickname ?? "").isEmpty
        isLoading = false
    }

    func toggleTask(_ task: Task) {
        guard let stats = userStats, let pet else { return }
        task.status = task.status == .completed ? .pending : .completed
        if task.status == .completed {
            _ = rewardEngine.applyTaskReward(for: task, stats: stats)
            petEngine.applyTaskCompletion(pet: pet)
            analytics.log(event: "task_completed", metadata: ["title": task.title])
            if rewardEngine.evaluateAllClear(tasks: todayTasks, stats: stats) {
                analytics.log(event: "streak_up", metadata: ["streak": "\(stats.TotalDays)"])
            }
            logTodayEnergySnapshot()
        }
        storage.persist()
        todayTasks = storage.fetchTasks(for: .now)
    }

    func petting() {
        guard let pet else { return }
        petEngine.handleAction(.pat, pet: pet)
        storage.persist()
        objectWillChange.send()
        analytics.log(event: "pet_pat")
    }

    func feed(item: Item) {
        guard let pet else { return }
        petEngine.handleAction(.feed(item: item), pet: pet)
        storage.persist()
    }

    func purchase(item: Item) -> Bool {
        guard let stats = userStats else { return false }
        let success = rewardEngine.purchase(item: item, stats: stats)
        guard success else { return false }
        incrementInventory(for: item)
        analytics.log(event: "shop_purchase", metadata: ["sku": item.sku])
        logTodayEnergySnapshot()
        return true
    }

    func updateProfile(nickname: String, region: String) {
        userStats?.nickname = nickname
        userStats?.region = region
        showOnboarding = false
        storage.persist()
        analytics.log(event: "onboarding_done", metadata: ["region": region])
    }

    func requestNotifications() {
        notificationService.requestAuthorization { [weak self] granted in
            guard let self, let stats = self.userStats else { return }
            stats.notificationsEnabled = granted
            if granted {
                self.notificationService.scheduleDailyReminders()
            }
            self.storage.persist()
        }
    }

    func sendChat(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatMessages.append(ChatMessage(role: .user, content: text))
        let reply = chatService.reply(
            to: text,
            weather: weather,
            mood: pet?.mood ?? .calm
        )
        chatMessages.append(ChatMessage(role: .pet, content: reply))
        analytics.log(event: "chat_message")
    }

    func persistState() {
        storage.persist()
    }

    func addMoodEntry(value: Int) {
        let entry = MoodEntry(value: value)
        storage.saveMoodEntry(entry)
        moodEntries = storage.fetchMoodEntries()
    }

    func incrementInventory(for item: Item) {
        storage.incrementInventory(forSKU: item.sku)
        inventory = storage.fetchInventory()
    }

    func useItem(sku: String) -> Bool {
        guard let pet else { return false }
        // Check inventory count first
        if let entry = inventory.first(where: { $0.sku == sku }), entry.count > 0,
           let item = shopItems.first(where: { $0.sku == sku }) {
            storage.decrementInventory(forSKU: sku)
            inventory = storage.fetchInventory()
            petEngine.handleAction(.feed(item: item), pet: pet)
            storage.persist()
            analytics.log(event: "item_used", metadata: ["sku": sku])
            logTodayEnergySnapshot()
            return true
        } else {
            return false
        }
    }

    var completionRate: Double {
        guard !todayTasks.isEmpty else { return 0 }
        let completed = todayTasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(todayTasks.count)
    }

    private func logTodayEnergySnapshot() {
        guard userStats != nil else { return }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: Date())

        if let index = energyHistory.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
            energyHistory[index].totalEnergy = totalEnergy
        } else {
            let entry = EnergyHistoryEntry(id: UUID(), date: dayStart, totalEnergy: totalEnergy)
            energyHistory.append(entry)
        }

        energyHistory.sort { $0.date < $1.date }

        if let data = try? JSONEncoder().encode(energyHistory) {
            UserDefaults.standard.set(data, forKey: "energyHistory")
        }
    }

    func ensureInitialTasks(minimum: Int = 3) {
        guard minimum > 0 else { return }

        // 已经满足数量要求则直接返回
        if todayTasks.count >= minimum { return }

        // 使用统一的 TaskGeneratorService / 任务配置作为唯一来源补足任务
        let generated = taskGenerator.generateTasks(for: .now, weather: weather)

        guard !generated.isEmpty else {
            storage.persist()
            return
        }

        // 避免重复：保留已存在的 todayTasks，只从生成结果中补足缺口
        let existingIDs = Set(todayTasks.map { $0.id })
        let remaining = minimum - todayTasks.count
        if remaining > 0 {
            let extras = generated.filter { !existingIDs.contains($0.id) }
            todayTasks.append(contentsOf: extras.prefix(remaining))
        }

        storage.persist()
    }
}
