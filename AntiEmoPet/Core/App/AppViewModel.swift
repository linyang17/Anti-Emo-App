import Foundation
import SwiftUI
import SwiftData
import Combine

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

    func load() {
        storage.bootstrapIfNeeded()
        weather = weatherService.fetchWeather()
        pet = storage.fetchPet()
        userStats = storage.fetchStats()
        shopItems = storage.fetchShopItems()

        todayTasks = storage.fetchTasks(for: .now)
        if todayTasks.isEmpty {
            todayTasks = taskGenerator.generateTasks(for: .now, weather: weather)
        }

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
                analytics.log(event: "streak_up", metadata: ["streak": "\(stats.streakDays)"])
            }
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
        feed(item: item)
        analytics.log(event: "shop_purchase", metadata: ["sku": item.sku])
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

    var completionRate: Double {
        guard !todayTasks.isEmpty else { return 0 }
        let completed = todayTasks.filter { $0.status == .completed }.count
        return Double(completed) / Double(todayTasks.count)
    }
}
