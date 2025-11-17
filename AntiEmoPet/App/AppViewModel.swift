import Foundation
import SwiftUI
import SwiftData
import Combine
import CoreLocation
import UIKit

extension Font {
	static func app(_ size: CGFloat) -> Font {
		FontTheme.ABeeZee(size)
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
	@Published var sunEvents: [Date: SunTimes] = [:]
	@Published var isLoading = true
	@Published var showOnboarding = false
	@Published var moodEntries: [MoodEntry] = []
	@Published var energyHistory: [EnergyHistoryEntry] = []
	@Published var inventory: [InventoryEntry] = []
	@Published var dailyMetricsCache: [DailyActivityMetrics] = []
	@Published var showSleepReminder = false
	@Published var rewardBanner: RewardEvent?
	@Published var currentLanguage: String = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        @Published var shouldShowNotificationSettingsPrompt = false
	@Published private(set) var hasLoggedMoodToday = false
	@Published var shouldForceMoodCapture = false
	@Published var pendingMoodFeedbackTask: UserTask?

	let locationService = LocationService()
	private let storage: StorageService
	private let taskGenerator: TaskGeneratorService
	private let rewardEngine = RewardEngine()
	private let petEngine = PetEngine()
	private let notificationService = NotificationService()
	private let weatherService = WeatherService()
	private let analytics = AnalyticsService()
	private var cancellables: Set<AnyCancellable> = []
	private let sleepReminderService = SleepReminderService()
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
		bindSleepReminder()
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

	/// Update app language and persist to UserDefaults.
	func setLanguage(_ code: String) {
		currentLanguage = code
		UserDefaults.standard.set(code, forKey: "selectedLanguage")
	}

	func load() async {
		storage.bootstrapIfNeeded()
		pet = storage.fetchPet()
		userStats = storage.fetchStats()

		// Ensure initial defaults per MVP PRD
		if let stats = userStats, stats.totalEnergy <= 0 {
			stats.totalEnergy = 100
		}

		// Load stored energy history (for daily totalEnergy snapshots)
		if let data = UserDefaults.standard.data(forKey: "energyHistory"),
		   let decoded = try? JSONDecoder().decode([EnergyHistoryEntry].self, from: data) {
			energyHistory = decoded
		}
		// Removed fallback else block that initialized today's snapshot

		if let pet = pet {
			// XP baseline should start at 0 if negative
			if pet.xp < 0 { pet.xp = 0 }
		}

		shopItems = StaticItemLoader.loadAllItems()

		moodEntries = storage.fetchMoodEntries()
		refreshMoodLoggingState()
		sunEvents = storage.fetchSunEvents()
		inventory = storage.fetchInventory()

		todayTasks = storage.fetchTasks(for: .now)

		if let stats = userStats, stats.shareLocationAndWeather {
			beginLocationUpdates()
		}

		await refreshWeather(using: locationService.lastKnownLocation)
                storage.resetAllCompletionDates()

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
		recordMoodOnLaunch()
	}
	
	func refreshIfNeeded() async {
		await load()
	}
	
	/// 开始任务,设置buffer时间
	func startTask(_ task: UserTask) {
		guard task.status == .pending else { return }
		
		let now = Date()
		task.status = .started
		task.startedAt = now
		task.canCompleteAfter = now.addingTimeInterval(task.category.bufferDuration)
		
		storage.persist()
		todayTasks = storage.fetchTasks(for: .now)
		
		analytics.log(event: "task_started", metadata: [
			"title": task.title,
			"category": task.category.rawValue,
			"buffer": "\(task.category.bufferDuration)"
		])
		
		// 设置定时器在buffer时间后更新状态为ready
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: UInt64(task.category.bufferDuration * 1_000_000_000))
			if task.status == .started, let canComplete = task.canCompleteAfter, Date() >= canComplete {
				task.status = .ready
				storage.persist()
				todayTasks = storage.fetchTasks(for: .now)
				objectWillChange.send()
			}
		}
	}

	func completeTask(_ task: UserTask) {
		guard let stats = userStats, let pet, task.status != .completed else { return }
		
		// 检查是否可以完成:pending直接完成,或者已达到buffer时间
		guard task.status.isCompletable else { return }
		if task.status == .started, let canComplete = task.canCompleteAfter, Date() < canComplete {
			// 未到buffer时间,不能完成
			return
		}
		task.status = .completed
		task.completedAt = Date()
		
		// 确保使用category标准能量奖励
		task.energyReward = task.category.energyReward
		let energyReward = rewardEngine.applyTaskReward(for: task, stats: stats)
		petEngine.applyTaskCompletion(pet: pet)
		analytics.log(event: "task_completed", metadata: ["title": task.title])
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		incrementTaskCompletion(for: Date(), timeSlot: slot)
		if rewardEngine.evaluateAllClear(tasks: todayTasks, stats: stats) {
			analytics.log(event: "streak_up", metadata: ["streak": "\(stats.TotalDays)"])
		}
		rewardBanner = RewardEvent(energy: energyReward, xp: 1)
		logTodayEnergySnapshot()
		dailyMetricsCache = makeDailyActivityMetrics()
		storage.persist()
		todayTasks = storage.fetchTasks(for: .now)
		
		// 触发强制情绪反馈弹窗
		pendingMoodFeedbackTask = task
	}
	
	/// 提交任务完成后的情绪反馈
	/// - Parameters:
	///   - delta: 情绪变化值 (-5: 更差, 0: 无变化, +5: 更好, +10: 好很多)
	///   - task: 完成的任务
	func submitMoodFeedback(delta: Int, for task: UserTask) {
		let entry = MoodEntry(
			date: Date(),
			value: max(10, min(100, 50 + delta)), // 基准值50,加上delta并限制在10-100范围
			source: .afterTask,
			delta: delta,
			relatedTaskCategory: task.category,
			relatedWeather: weather
		)
		storage.saveMoodEntry(entry)
		moodEntries = storage.fetchMoodEntries()
		
		analytics.log(event: "mood_feedback_after_task", metadata: [
			"delta": "\(delta)",
			"category": task.category.rawValue,
			"weather": weather.rawValue
		])
		
		// 清除待处理的反馈任务
		pendingMoodFeedbackTask = nil
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
		accountEmail: String,
		Onboard: Bool
	) {
		userStats?.nickname = nickname
		userStats?.region = region
		userStats?.shareLocationAndWeather = shareLocation
		userStats?.gender = gender
		userStats?.birthday = birthday
		userStats?.accountEmail = accountEmail
		userStats?.Onboard = true
		storage.persist()
		showOnboarding = false
		if shareLocation {
			beginLocationUpdates()
		}
		storage.resetCompletionDates(for: Date())
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
		shouldShowNotificationSettingsPrompt = false
		notificationService.requestNotiAuth { [weak self] result in
			guard let self, let stats = self.userStats else { return }
			switch result {
			case .granted:
				stats.notificationsEnabled = true
				self.notificationService.scheduleDailyReminders()
				self.scheduleTaskNotifications()
			case .denied:
				stats.notificationsEnabled = false
			case .requiresSettings:
				stats.notificationsEnabled = false
				self.shouldShowNotificationSettingsPrompt = true
			}
			self.storage.persist()
		}
	}

	func openNotificationSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		UIApplication.shared.open(url)
	}

	func persistState() {
		storage.persist()
	}

	func consumeRewardBanner() {
		rewardBanner = nil
	}

	func addMoodEntry(
		value: Int,
		source: MoodEntry.Source = .appOpen,
		delta: Int? = nil,
		relatedTaskCategory: TaskCategory? = nil,
		relatedWeather: WeatherType? = nil
	) {
		let entry = MoodEntry(
			value: value,
			source: source,
			delta: delta,
			relatedTaskCategory: relatedTaskCategory,
			relatedWeather: relatedWeather ?? weatherReport?.currentWeather
		)
		storage.saveMoodEntry(entry)
		moodEntries = storage.fetchMoodEntries()
		
		// 刷新今日情绪记录状态
		refreshMoodLoggingState()
		
		// 如果是应用打开时的记录,关闭强制弹窗
		if source == .appOpen {
			shouldForceMoodCapture = false
		}
		
		analytics.log(event: "mood_entry_added", metadata: [
			"source": source.rawValue,
			"value": "\(value)"
		])
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
                storage.resetAllCompletionDates()
		if let retained {
			retained.status = .pending
			retained.completedAt = nil
		}
		storage.resetCompletionDates(for: Date())
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
		if !report.sunEvents.isEmpty {
			storage.saveSunEvents(report.sunEvents)
			let merged = storage.fetchSunEvents()
			sunEvents = merged
		}
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

	private func bindSleepReminder() {
		sleepReminderService.$isReminderDue
			.receive(on: RunLoop.main)
			.assign(to: &$showSleepReminder)
	}

	private func configureSleepReminderMonitoring() {
		sleepReminderService.startMonitoring()
	}

	func dismissSleepReminder() {
		sleepReminderService.acknowledgeReminder()
	}

	private func refreshMoodLoggingState(reference date: Date = Date()) {
		let calendar = TimeZoneManager.shared.calendar
		let startOfDay = calendar.startOfDay(for: date)
		let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
		let loggedToday = moodEntries.contains { entry in
			entry.date >= startOfDay && entry.date < endOfDay
		}
		hasLoggedMoodToday = loggedToday
		shouldForceMoodCapture = !loggedToday
	}

	private func recordMoodOnLaunch() {
		refreshMoodLoggingState()
		if !hasLoggedMoodToday {
			shouldForceMoodCapture = true
		}
	}
}
