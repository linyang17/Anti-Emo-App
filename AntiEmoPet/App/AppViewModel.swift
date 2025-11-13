import Foundation
import SwiftUI
import SwiftData
import Combine
import CoreLocation

struct EnergyHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    var totalEnergy: Int

    init(id: UUID = UUID(), date: Date, totalEnergy: Int) {
        self.id = id
        self.date = date
        self.totalEnergy = totalEnergy
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var todayTasks: [UserTask] = []
    @Published var pet: Pet?
    @Published var userStats: UserStats?
    @Published var shopItems: [Item] = []
    @Published var weather: WeatherType = .sunny
    @Published var weatherReport: WeatherReport?
    @Published var chatMessages: [ChatMessage] = []
    @Published var isLoading = true
    @Published var showOnboarding = false
    @Published var moodEntries: [MoodEntry] = []
    @Published var energyHistory: [EnergyHistoryEntry] = []
    @Published var inventory: [InventoryEntry] = []
    @Published var dailyMetricsCache: [DailyActivityMetrics] = []
    @Published var showSleepReminder = false

    let locationService = LocationService()
    private let storage: StorageService
    private let taskGenerator: TaskGeneratorService
    private let rewardEngine = RewardEngine()
    private let petEngine = PetEngine()
    private let notificationService = NotificationService()
    private let weatherService = WeatherService()
    private let chatService = ChatService()
    private let analytics = AnalyticsService()
    private var cancellables: Set<AnyCancellable> = []
    private var sleepTimer: AnyCancellable?
    private let isoDayFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        // Persisted day keys were historically written in UTC.
        // Keep the formatter pinned to GMT to avoid reinterpreting legacy data
        // using the user's current timezone, which would shift stored metrics.
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(modelContext: ModelContext) {
        storage = StorageService(context: modelContext)
        taskGenerator = TaskGeneratorService(storage: storage)
        bindLocationUpdates()
        configureSleepReminderMonitoring()
    }

    var totalEnergy: Int {
        userStats?.totalEnergy ?? 0
    }

    var allTasks: [UserTask] {
        // MVP 阶段：全部任务等于今日任务列表
        // 未来如加入历史/模板任务库，只需在此改为从 StorageService / TaskGenerator 获取
        todayTasks
    }

    func load() async {
        storage.bootstrapIfNeeded()
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
        }
        // Removed fallback else block that initialized today's snapshot

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

        if let stats = userStats, stats.shareLocationAndWeather {
            beginLocationUpdates()
        }

        await refreshWeather(using: locationService.lastKnownLocation)

        if todayTasks.isEmpty {
            let generated = taskGenerator.generateDailyTasks(for: Date(), report: weatherReport)
            storage.save(tasks: generated)
            todayTasks = generated
        } else {
            weather = weatherReport?.currentWeather ?? weather
        }

        scheduleTaskNotifications()

        showOnboarding = !(userStats?.Onboard ?? false)
        isLoading = false

        dailyMetricsCache = makeDailyActivityMetrics(days: 7)
    }
	
	func refreshIfNeeded() async {
		// 应用从后台回到前台时，刷新必要数据
		// 比如重新同步任务、天气、统计等
		await load()
	}

    func toggleTask(_ task: UserTask) {
        guard let stats = userStats, let pet else { return }
        task.status = task.status == .completed ? .pending : .completed
        if task.status == .completed {
            task.completedAt = Date()
            _ = rewardEngine.applyTaskReward(for: task, stats: stats)
            petEngine.applyTaskCompletion(pet: pet)
            analytics.log(event: "task_completed", metadata: ["title": task.title])
            let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
            incrementTaskCompletion(for: Date(), timeSlot: slot)
            if rewardEngine.evaluateAllClear(tasks: todayTasks, stats: stats) {
                analytics.log(event: "streak_up", metadata: ["streak": "\(stats.TotalDays)"])
            }
            logTodayEnergySnapshot()
            dailyMetricsCache = makeDailyActivityMetrics()
        } else {
            task.completedAt = nil
        }
        storage.persist()
        todayTasks = storage.fetchTasks(for: .now)
    }

    func petting() {
        guard let pet else { return }
        petEngine.handleAction(.pat, pet: pet)
        incrementPetInteractionCount()
        storage.persist()
        objectWillChange.send()
        analytics.log(event: "pet_pat")
        dailyMetricsCache = makeDailyActivityMetrics()
    }

    func feed(item: Item) {
        guard let pet else { return }
        petEngine.handleAction(.feed(item: item), pet: pet)
        incrementPetInteractionCount()
        storage.persist()
        dailyMetricsCache = makeDailyActivityMetrics()
    }

    func purchase(item: Item) -> Bool {
        guard let stats = userStats, let pet else { return false }
        let success = rewardEngine.purchase(item: item, stats: stats)
        guard success else { return false }
        incrementInventory(for: item)
        petEngine.applyPurchaseReward(pet: pet)
        storage.persist()
        objectWillChange.send()
        analytics.log(event: "shop_purchase", metadata: ["sku": item.sku])
        logTodayEnergySnapshot()
        return true
    }

    func updateProfile(
        nickname: String,
        region: String,
        shareLocation: Bool,
        gender: String,
        birthday: Date?,
		Onboard: Bool
    ) {
        userStats?.nickname = nickname
        userStats?.region = region
        userStats?.shareLocationAndWeather = shareLocation
        userStats?.gender = gender
        userStats?.birthday = birthday
		userStats?.Onboard = true
        storage.persist()
        showOnboarding = false
        if shareLocation {
            beginLocationUpdates()
        }
        storage.deleteTasks(for: Date())
        let starter = taskGenerator.makeOnboardingTasks(for: Date())
        storage.save(tasks: starter)
        todayTasks = storage.fetchTasks(for: .now)
        scheduleTaskNotifications()
        analytics.log(
            event: "onboarding_done",
            metadata: [
                "region": region,
                "gender": gender
            ]
        )
    }

    func requestNotifications() {
        notificationService.requestAuthorization { [weak self] granted in
            guard let self, let stats = self.userStats else { return }
            stats.notificationsEnabled = granted
            if granted {
                self.notificationService.scheduleDailyReminders()
                self.scheduleTaskNotifications()
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
            bonding: pet?.bonding ?? .calm
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

    func isEquipped(_ item: Item) -> Bool {
        guard let pet else { return false }
        return pet.decorations.contains(item.assetName)
    }

    func equip(item: Item) {
        guard let pet, !item.assetName.isEmpty else { return }
        if !pet.decorations.contains(item.assetName) {
            pet.decorations.append(item.assetName)
            storage.persist()
            objectWillChange.send()
        }
    }

    func unequip(item: Item) {
        guard let pet else { return }
        let countBefore = pet.decorations.count
        pet.decorations.removeAll { $0 == item.assetName }
        guard pet.decorations.count != countBefore else { return }
        storage.persist()
        objectWillChange.send()
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
		_ = TimeZoneManager.shared.calendar
        // Always append a new entry with exact timestamp Date()
        let entry = EnergyHistoryEntry(date: Date(), totalEnergy: totalEnergy)
        energyHistory.append(entry)

        energyHistory.sort { $0.date < $1.date }

        if let data = try? JSONEncoder().encode(energyHistory) {
            UserDefaults.standard.set(data, forKey: "energyHistory")
        }
    }

    private var interactionsKey: String { "dailyPetInteractions" }
    private var timeSlotKey: String { "dailyTaskTimeSlots" }

    private func dayKey(for date: Date) -> String {
        let cal = TimeZoneManager.shared.calendar
        let day = cal.startOfDay(for: date)
        return isoDayFormatter.string(from: day)
    }

    private func incrementPetInteractionCount(on date: Date = Date()) {
        var dict = (UserDefaults.standard.dictionary(forKey: interactionsKey) as? [String: Int]) ?? [:]
        let dkey = dayKey(for: date)
        dict[dkey, default: 0] += 1
        UserDefaults.standard.set(dict, forKey: interactionsKey)
    }

    private func incrementTaskCompletion(for date: Date = Date(), timeSlot: TimeSlot) {
        var outer = (UserDefaults.standard.dictionary(forKey: timeSlotKey) as? [String: [String: Int]]) ?? [:]
        let dkey = dayKey(for: date)
        var inner = outer[dkey] ?? [:]
        inner[timeSlot.rawValue, default: 0] += 1
        outer[dkey] = inner
        UserDefaults.standard.set(outer, forKey: timeSlotKey)
    }

    func makeDailyActivityMetrics(days: Int = 7) -> [DailyActivityMetrics] {
        let cal = TimeZoneManager.shared.calendar
        let now = Date()
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(1, days) - 1), to: now)!)

        let interactions = (UserDefaults.standard.dictionary(forKey: interactionsKey) as? [String: Int]) ?? [:]
        let timeSlots = (UserDefaults.standard.dictionary(forKey: timeSlotKey) as? [String: [String: Int]]) ?? [:]

        var metricsByDay: [Date: DailyActivityMetrics] = [:]

        // Merge interactions
        for (k, v) in interactions {
            if let date = isoDayFormatter.date(from: k) {
                let day = cal.startOfDay(for: date)
                guard day >= start else { continue }
                var m = metricsByDay[day] ?? DailyActivityMetrics(date: day)
                m.petInteractionCount += v
                metricsByDay[day] = m
            }
        }

        // Merge time slot counts
        for (k, inner) in timeSlots {
            if let date = isoDayFormatter.date(from: k) {
                let day = cal.startOfDay(for: date)
                guard day >= start else { continue }
                var m = metricsByDay[day] ?? DailyActivityMetrics(date: day)
                for (slotRaw, count) in inner {
                    if let slot = TimeSlot(rawValue: slotRaw) {
                        m.timeSlotTaskCounts[slot, default: 0] += count
                        m.completedTaskCount += count
                    }
                }
                metricsByDay[day] = m
            }
        }

        // Only return days that have any activity
        return metricsByDay.values.sorted { $0.date < $1.date }
    }

    func beginLocationUpdates() {
        locationService.startUpdating()
    }

    func stopLocationUpdates() {
        locationService.stopUpdating()
    }

    func requestWeatherAccess() async -> Bool {
        let granted = await weatherService.checkLocationAuthorization()
        locationService.updateWeatherPermission(granted: granted)
        return granted
    }

    func refreshTasks(retaining retained: UserTask? = nil) async {
        let retainIDs: Set<UUID>
        if let retained {
            retainIDs = [retained.id]
        } else {
            retainIDs = []
        }
        var reservedTitles: Set<String> = []
        if let retained {
            reservedTitles.insert(retained.title)
        }
        if let stats = userStats, stats.shareLocationAndWeather {
            beginLocationUpdates()
        }
        await refreshWeather(using: locationService.lastKnownLocation)
        if let retained {
            retained.status = .pending
            retained.completedAt = nil
        }
        storage.deleteTasks(for: Date(), excluding: retainIDs)
        let generated = taskGenerator.generateDailyTasks(for: Date(), report: weatherReport, reservedTitles: reservedTitles)
        storage.save(tasks: generated)
        todayTasks = storage.fetchTasks(for: .now)
        scheduleTaskNotifications()
    }

    func scheduleTaskNotifications() {
        guard userStats?.notificationsEnabled == true else { return }
        notificationService.scheduleTaskReminders(for: todayTasks)
    }

    private func refreshWeather(using location: CLLocation?) async {
		let locality = locationService.lastKnownCity
        let report = await weatherService.fetchWeather(for: location, locality: locality)
        weatherReport = report
        weather = report.currentWeather
        if let city = report.locality, !(city.isEmpty) {
            userStats?.region = city
            storage.persist()
        }
    }

    private func bindLocationUpdates() {
        locationService.$lastKnownCity
            .compactMap { $0 }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] city in
                guard let self, !city.isEmpty else { return }
                self.userStats?.region = city
                self.storage.persist()
            }
            .store(in: &cancellables)

        locationService.$lastKnownLocation
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                guard let self else { return }
                Task { await self.refreshWeather(using: location) }
            }
            .store(in: &cancellables)
    }

    private func configureSleepReminderMonitoring() {
        sleepTimer?.cancel()
        let publisher = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
        sleepTimer = publisher
            .sink { [weak self] date in
                self?.evaluateSleepReminder(at: date)
            }
        evaluateSleepReminder(at: Date())
    }

    private func evaluateSleepReminder(at date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        showSleepReminder = hour >= 22 || hour < 6
    }
}
