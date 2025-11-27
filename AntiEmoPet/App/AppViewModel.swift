import Foundation
import SwiftUI
import SwiftData
import Combine
import CoreLocation
import UIKit
import OSLog


@MainActor
final class AppViewModel: ObservableObject {
	@Published var todayTasks: [UserTask] = [] {
		didSet {
			updateTaskRefreshEligibility()
		}
	}
	@Published var pet: Pet? { didSet {petEngine.updatePetReference(pet) }}
	@Published var userStats: UserStats?
	@Published var shopItems: [Item] = []
	@Published var weatherReport: WeatherReport?
	var weather: WeatherType { weatherReport?.currentWeather ?? .sunny }
	@Published var sunEvents: [Date: SunTimes] = [:]
	@Published var isLoading = true
	@Published var showOnboarding = true
	@Published var showOnboardingCelebration = false
	@Published var moodEntries: [MoodEntry] = []
	@Published var energyHistory: [EnergyHistoryEntry] = []
	@Published var inventory: [InventoryEntry] = []
	@Published var dailyMetricsCache: [DailyActivityMetrics] = []
	@Published var showSleepReminder = false
	@Published var rewardBanner: RewardEvent?
	@Published var currentLanguage: String = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
	@Published var shouldShowNotificationSettingsPrompt = false
	@Published private(set) var hasLoggedMoodThisSlot = false
	@Published var showMoodCapture = false
	@Published var shouldForceMoodCapture = false
	@Published var pendingMoodFeedbackTask: UserTask?
	@Published private(set) var canRefreshCurrentSlot = false
	@Published private(set) var hasUsedRefreshThisSlot = false
	@Published var pettingNotice: String?
	lazy var petEngine = PetEngine(pet: nil)

	let locationService = LocationService()
	let storage: StorageService
	let taskGenerator: TaskGeneratorService
	private let rewardEngine = RewardEngine()
	private let notificationService = NotificationService()
	private let weatherService = WeatherService()
	private let analytics = AnalyticsService()
	private var cancellables: Set<AnyCancellable> = []
	private let sleepReminderService = SleepReminderService()
	private let logger = Logger(subsystem: "com.Lumio.pet", category: "AppViewModel")
	private let refreshRecordsKey = "taskRefreshRecords"
	private let slotScheduleKey = "taskSlotSchedule"
	private let slotGenerationKey = "taskSlotGenerationRecords"
	private let penaltyRecordsKey = "taskSlotPenaltyRecords"
	private let pettingLimitKey = "dailyPettingLimit"
	private var lastObservedSlot: TimeSlot?
	private typealias RefreshRecordMap = [String: [String: Double]]
	private typealias SlotScheduleMap = [String: [String: Double]]
	private typealias SlotGenerationMap = [String: [String: Bool]]
	private typealias SlotPenaltyMap = [String: [String: Bool]]
	private var slotMonitorTask: Task<Void, Never>?
	private var pettingNoticeTask: Task<Void, Never>?
	private let isoDayFormatter: ISO8601DateFormatter = {
	let formatter = ISO8601DateFormatter()
	formatter.formatOptions = [.withFullDate]
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	return formatter
	}()

	// MARK: - Initialization
	init(modelContext: ModelContext) {
		storage = StorageService(context: modelContext)
		taskGenerator = TaskGeneratorService(storage: storage)
		bindLocationUpdates()
		bindSleepReminder()
		configureSleepReminderMonitoring()
	}

	deinit {
		slotMonitorTask?.cancel()
		pettingNoticeTask?.cancel()
	}

	// MARK: - Core Properties
	var totalEnergy: Int {
		userStats?.totalEnergy ?? 0
	}
	
	// MARK: - Load data
	
	/// Initial load for users who haven't completed onboarding.
	/// Clears onboarding cache and determines whether the onboarding flow should be presented.
	func initLoad() async {
		logger.info("Initialising pre-onboarding state.")
		await OnboardingCache.shared.clear()
		
		if let stats = userStats {
			let storedComponents = RegionComponents(
				locality: stats.regionLocality,
				administrativeArea: stats.regionAdministrativeArea,
				country: stats.regionCountry
			)
			if !storedComponents.formatted.isEmpty {
				applyRegionComponents(storedComponents)
			}
		}
		showOnboarding = !(userStats?.Onboard ?? false)
		isLoading = false
	}
	
	/// Full load for users who have completed onboarding
	func load() async {
		logger.info("Loading app data…")
		
		storage.bootstrapIfNeeded()
		pet = storage.fetchPet()
		userStats = storage.fetchStats()

		await loadCachedData()
		
		scheduleTaskNotifications()
		prepareSlotGenerationSchedule(for: Date())
		
		// onboarding阶段没有数据缓存
		showOnboarding = !(userStats?.Onboard ?? false)
		guard !showOnboarding else {
			await initLoad()
			await fetchInitialWeather()
			return
		}
		
		moodEntries = storage.fetchMoodEntries()
		refreshMoodLoggingState()

		// 优先使用上次缓存的城市填充用户信息，避免 Profile 中城市为空
		let cachedCity = locationService.lastKnownCity
		if !cachedCity.isEmpty, userStats?.region.isEmpty == true {
			userStats?.region = cachedCity
		}
		
		if let stats = userStats, stats.totalEnergy <= 0 {
			stats.totalEnergy = 0
		}

		// Load stored energy history (for daily totalEnergy snapshots)
		if let data = UserDefaults.standard.data(forKey: "energyHistory"),
		   let decoded = try? JSONDecoder().decode([EnergyHistoryEntry].self, from: data) {
			energyHistory = decoded
		}
		
		applyDailyBondingDecayIfNeeded()
		
		await refreshWeather(using: locationService.lastKnownLocation)
		
		// Determine current slot
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		todayTasks = storage.fetchTasks(in: slot, on: Date(), includeOnboarding: true)

		if todayTasks.isEmpty {
			let generated = taskGenerator.generateTasks(
				for: slot,
				date: Date(),
				report: weatherReport
			)
			storage.save(tasks: generated)
			todayTasks = generated
			logger.debug("Generated initial daily tasks: \(generated.count)")
		}

		checkSlotGenerationTrigger()
		startSlotMonitor()
		
		// Check sleep reminder and mood capture
		if !showSleepReminder {
			checkAndShowMoodCapture()
		}

		isLoading = false
		dailyMetricsCache = makeDailyActivityMetrics(days: 7)
		recordMoodOnLaunch()
		
	}
	
	private func fetchInitialWeather() async {
			// Request location once when app opens
		if let stats = userStats, stats.shareLocationAndWeather {
			_ = await requestWeatherAccess()
			_ = await locationService.requestLocationOnce()
		}
		await refreshWeather(using: locationService.lastKnownLocation)
		let latString = locationService.lastKnownLocation.map { String($0.coordinate.latitude) } ?? "nil"
		let lonString = locationService.lastKnownLocation.map { String($0.coordinate.longitude) } ?? "nil"
		logger
			.info(
				"[AppViewModel] fetchInitialWeather: \(self.weatherReport?.currentWeather.rawValue ?? "nil"), for city: \(self.locationService.lastKnownCity), lat: \(latString), lon: \(lonString)"
			)
		
	}

	func refreshIfNeeded() async {
		logger.info("Refreshing app data…")
		await load()
		// 重新检查是否需要显示情绪记录弹窗（可能在后台时日期变化了）
		if !showOnboarding && !showSleepReminder {
			checkAndShowMoodCapture()
		}
	}
	
	// MARK: - Task Management

		/// 检查当前时段是否已记录情绪，如果没有则显示弹窗
		func checkAndShowMoodCapture() {
			refreshMoodLoggingState()
			let currentSlot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
			// Night 时段不需要强制情绪记录
			guard currentSlot != .night else {
				showMoodCapture = false
				shouldForceMoodCapture = false
				return
			}
			guard !hasLoggedMoodThisSlot else {
				showMoodCapture = false
				shouldForceMoodCapture = false
				return
			}
			shouldForceMoodCapture = true
			showMoodCapture = true
		}
	
        /// 记录情绪并关闭弹窗
        func recordMoodOnLaunch(value: Int? = nil) {
                refreshMoodLoggingState()
                guard let value else {
                        showMoodCapture = shouldForceMoodCapture
                        return
                }
                addMoodEntry(value: value, source: .appOpen)
                showMoodCapture = false
                shouldForceMoodCapture = false
				hasLoggedMoodThisSlot = true
        }

		// MARK: - Task Status Update
		@MainActor
		func updateTaskStatus(_ id: UUID, to newStatus: TaskStatus) {
			guard let index = todayTasks.firstIndex(where: { $0.id == id }) else {
				logger.error("updateTaskStatus: Task not found for id \(id, privacy: .public)")
				return
			}
			
			let task = todayTasks[index]
			let now = Date()
			
			switch newStatus {
			case .started:
				guard task.status == .pending else { return }
				task.status = .started
				task.startedAt = now
				task.canCompleteAfter = now.addingTimeInterval(task.category.bufferDuration)
				
				Task { @MainActor in
					try? await Task.sleep(nanoseconds: UInt64(task.category.bufferDuration * 1_000_000_000))
					if task.status == .started, let canComplete = task.canCompleteAfter, Date() >= canComplete {
						updateTaskStatus(id, to: .ready)
					}
				}
				
			case .ready:
				guard task.status == .started else { return }
				task.status = .ready
				task.canCompleteAfter = nil
				
			case .completed:
				guard task.status.isCompletable else { return }
				task.status = .completed
				task.completedAt = now
				completeTask(task)
				return

			case .pending:
				task.status = .pending
				task.startedAt = nil
				task.completedAt = nil
				task.canCompleteAfter = nil

			}

			todayTasks[index] = task
			storage.persist()
			// Only fetch tasks for the current slot to keep view clean, but include onboarding tasks
			let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
			todayTasks = storage.fetchTasks(in: slot, on: Date(), includeOnboarding: true)
			objectWillChange.send()
		}

	func refreshCurrentSlotTasks(retaining retained: UserTask? = nil) async {
		guard canRefreshCurrentSlot else { return }
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		await evaluateBondingPenalty(for: slot)
		await refreshTasks(retaining: retained)
		markCurrentSlotRefreshed()
		markSlotTasksGenerated(slot, on: Date())
		updateTaskRefreshEligibility()
		prepareSlotGenerationSchedule(for: Date())
		checkSlotGenerationTrigger()
	}
	
	// MARK: Start + complete tasks
	func startTask(_ task: UserTask) {
		guard task.status == .pending else { return }
		
		// Check if another task is already started (unless DEBUG)
		#if !DEBUG
		let hasActiveTask = todayTasks.contains { $0.status == .started }
		guard !hasActiveTask else { return }
		#endif
		
		let now = Date()
		task.status = .started
		task.startedAt = now
		task.canCompleteAfter = now.addingTimeInterval(task.category.bufferDuration)
		
		storage.persist()
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		todayTasks = storage.fetchTasks(in: slot, on: Date(), includeOnboarding: true)
		
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
				let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
				todayTasks = storage.fetchTasks(in: slot, on: Date(), includeOnboarding: true)
				objectWillChange.send()
			}
		}
	}

	func completeTask(_ task: UserTask) {
		guard let stats = userStats else { return }
		guard task.status.isCompletable else { return }
		if task.status == .started, let canComplete = task.canCompleteAfter, Date() < canComplete {
			// 未到buffer时间,不能完成
			return
		}
		
		task.status = .completed
		task.completedAt = Date()
		
		task.energyReward = task.category.energyReward
		let energyReward = rewardEngine.applyTaskReward(for: task, stats: stats)
		petEngine.applyTaskCompletion()

		// TODO: 随机掉落一份 snack 奖励
		var snackName: String?
		if let snack = rewardEngine.randomSnackReward(from: shopItems) {
			incrementInventory(for: snack)
			snackName = snackDisplayName(for: snack)
			analytics.log(event: "snack_reward", metadata: ["sku": snack.sku])
		}

		analytics.log(event: "task_completed", metadata: ["title": task.title])
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		incrementTaskCompletion(for: Date(), timeSlot: slot)
		if rewardEngine.evaluateAllClear(tasks: todayTasks, stats: stats) {
			analytics.log(event: "streak_up", metadata: ["streak": "\(stats.TotalDays)"])
		}
		rewardBanner = RewardEvent(energy: energyReward, xp: 1, snackName: snackName)
		logTodayEnergySnapshot()
		dailyMetricsCache = makeDailyActivityMetrics()
		storage.persist()
		todayTasks = storage.fetchTasks(in: slot, on: Date(), includeOnboarding: true)
		
		checkOnboardingCompletion()
		
		pendingMoodFeedbackTask = task
	}

	//MARK: Mood impact feedback
	func submitMoodFeedback(delta: Int, for task: TaskCategory) {
			let lastValue: Int = {
					let sorted = moodEntries.sorted { $0.date < $1.date }
					return sorted.last?.value ?? 50
			}()
			let entry = MoodEntry(
					date: Date(),
					value: max(10, min(100, lastValue + delta)),
					source: .afterTask,
					delta: delta,
					relatedTaskCategory: task,
					relatedWeather: weather
			)
	storage.saveMoodEntry(entry)
	moodEntries = storage.fetchMoodEntries()
	
	// Link mood entry to the task if available
	if let pendingTask = pendingMoodFeedbackTask {
		pendingTask.moodEntryId = entry.id
		storage.persist()
	}
	
	analytics.log(event: "mood_feedback_after_task", metadata: [
		"delta": "\(delta)",
		"category": task.rawValue,
		"weather": weather.rawValue
	])
	
	pendingMoodFeedbackTask = nil
	
	// Check if we should show onboarding celebration
	checkAndShowOnboardingCelebration()
}
	
// MARK: Pet actions
	@discardableResult
	func petting() -> Bool {
		let count = pettingCount()
		let maxcount = 3
		guard count < maxcount else {
				showPettingNotice("Lumio needs some rest now")
				return false
		}
		petEngine.applyPettingReward()
		incrementPetInteractionCount()
		incrementPettingCount()
		storage.persist()
		objectWillChange.send()
		analytics.log(event: "pet_pat", metadata: ["count": "\(count + 1)"])
		dailyMetricsCache = makeDailyActivityMetrics()
		let remaining = max(0, maxcount - (count + 1))
		showPettingNotice(remaining >= 0 ? "Played with Lumio, \(remaining)/\(maxcount) left" : "You've played with Lumio today")
		return true
	}

        func feed(item: Item) {
			petEngine.handleAction(.feed(item: item))
			incrementPetInteractionCount()
			storage.persist()
			dailyMetricsCache = makeDailyActivityMetrics()
	}

	func purchase(item: Item) -> Bool {
		guard let stats = userStats else { return false }
		let success = rewardEngine.purchase(item: item, stats: stats)
		guard success else { return false }
		incrementInventory(for: item)
		petEngine.applyPurchaseReward(xpGain: 10, bondingBoost: 10)
		
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
	) async {
		userStats?.nickname = nickname
		
		// Ensure region is populated - wait for location service if needed
		var finalRegion = region
		if finalRegion.isEmpty {
			finalRegion = await locationService.requestLocationOnce(isOnboarding: true)
			logger.debug("updateProfile resolved region: \(finalRegion, privacy: .public)")
		}
		
		// If still empty, use lastKnownCity as fallback
		if finalRegion.isEmpty {
			finalRegion = locationService.lastKnownCity
		}
		
		userStats?.region = finalRegion
		userStats?.shareLocationAndWeather = shareLocation
		userStats?.gender = gender
		userStats?.birthday = birthday
		userStats?.accountEmail = accountEmail
		userStats?.Onboard = true
		
		if let components = locationService.lastRegionComponents {
			applyRegionComponents(components)
		} else {
			let fallbackComponents = RegionComponents(locality: finalRegion, administrativeArea: "", country: "")
			applyRegionComponents(fallbackComponents)
		}
		
		// Generate tutorial tasks once upon finishing onboarding
		let onboardingTasks = taskGenerator.makeOnboardingTasks(for: Date(), weather: weather)
		storage.save(tasks: onboardingTasks)
		
		// Explicitly set todayTasks to the newly generated onboarding tasks
		todayTasks = onboardingTasks
		
		storage.persist()
		showOnboarding = false
		
		// Onboarding 完成后检查是否需要显示情绪记录弹窗
		if !showSleepReminder {
			checkAndShowMoodCapture()
		}
		analytics.log(
			event: "onboarding_done",
			metadata: [
				"region": finalRegion,
				"gender": gender
			]
		)
		
		// Transition into the fully loaded state after onboarding
		Task {
			await self.load()
		}
	}

	// MARK: Notifications
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
	private func showPettingNotice(_ message: String) {
		pettingNoticeTask?.cancel()
		pettingNotice = message
		pettingNoticeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 2_000_000_000)
			pettingNotice = nil
		}
	}

	// MARK: mood entry
	func addMoodEntry(
		value: Int,
		source: MoodEntry.MoodSource = .appOpen,
		delta: Int? = nil,
		relatedTaskCategory: TaskCategory? = nil,
		relatedWeather: WeatherType? = nil
	) {
                let entry = MoodEntry(
                        value: value,
                        source: MoodEntry.MoodSource(rawValue: source.rawValue) ?? .appOpen,
                        delta: delta,
                        relatedTaskCategory: relatedTaskCategory,
                        relatedWeather: relatedWeather ?? weather
                )
				storage.saveMoodEntry(entry)
				moodEntries = storage.fetchMoodEntries()
		
                refreshMoodLoggingState()

                if source == .appOpen {
                        shouldForceMoodCapture = false
                        showMoodCapture = false
                }
		
		analytics.log(event: "mood_entry_added", metadata: [
			"source": source.rawValue,
			"value": "\(value)"
		])
	}

	func incrementInventory(for item: Item) {
		Task {
			await storage.addInventory(forSKU: item.sku)
			let updatedInventory = await storage.fetchInventory()
			await MainActor.run {
				self.inventory = updatedInventory
			}
		}
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
		// Check inventory count first
		if let entry = inventory.first(where: { $0.sku == sku }), entry.count > 0,
		   let item = shopItems.first(where: { $0.sku == sku }) {
			storage.decrementInventory(forSKU: sku)
			inventory = storage.fetchInventory()
			petEngine.handleAction(.feed(item: item))
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

	func logTodayEnergySnapshot() {
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

	private func updateTaskRefreshEligibility(reference date: Date = Date()) {
		let calendar = TimeZoneManager.shared.calendar
		let slot = TimeSlot.from(date: date, using: calendar)
		let elapsedSlots = elapsedTaskSlots(before: slot, on: date)
		for pastSlot in elapsedSlots {
			Task { await evaluateBondingPenalty(for: pastSlot, reference: date) }
		}
		let alreadyRefreshed = hasRefreshedTasks(for: slot, on: date)
		hasUsedRefreshThisSlot = alreadyRefreshed
		let allCompleted = !todayTasks.isEmpty && todayTasks.allSatisfy { $0.status == .completed }
		canRefreshCurrentSlot = allCompleted && !alreadyRefreshed
	}

	private func hasRefreshedTasks(for slot: TimeSlot, on date: Date = Date()) -> Bool {
		let records = loadRefreshRecords()
		let dkey = dayKey(for: date)
		guard let slotDict = records[dkey], let timestamp = slotDict[slot.rawValue] else {
			return false
		}
		let storedDate = Date(timeIntervalSince1970: timestamp)
		return TimeZoneManager.shared.calendar.isDate(storedDate, inSameDayAs: date)
	}

	private func markCurrentSlotRefreshed(on date: Date = Date()) {
		var records = loadRefreshRecords()
		let dkey = dayKey(for: date)
		let slot = TimeSlot.from(date: date, using: TimeZoneManager.shared.calendar)
		var slotDict = records[dkey] ?? [:]
		slotDict[slot.rawValue] = date.timeIntervalSince1970
		records = purgeRefreshRecords(records, keepingDay: dkey)
		records[dkey] = slotDict
		saveRefreshRecords(records)
		hasUsedRefreshThisSlot = true
	}

	private func loadRefreshRecords() -> RefreshRecordMap {
		(UserDefaults.standard.dictionary(forKey: refreshRecordsKey) as? RefreshRecordMap) ?? [:]
	}

	private func saveRefreshRecords(_ records: RefreshRecordMap) {
		UserDefaults.standard.set(records, forKey: refreshRecordsKey)
	}

	private func purgeRefreshRecords(_ records: RefreshRecordMap, keepingDay currentDay: String) -> RefreshRecordMap {
		var filtered: RefreshRecordMap = [:]
		if let current = records[currentDay] {
			filtered[currentDay] = current
		}
		return filtered
	}

	private func prepareSlotGenerationSchedule(for date: Date) {
		let dkey = dayKey(for: date)
		var schedule = purgeSlotSchedule(loadSlotSchedule(), keepingDay: dkey)
		var slotMap = schedule[dkey] ?? [:]
		for slot in activeTaskSlots where slotMap[slot.rawValue] == nil {
			if let trigger = taskGenerator.generationTriggerTime(for: slot, date: date, report: weatherReport) {
				slotMap[slot.rawValue] = trigger.timeIntervalSince1970
			}
		}
		schedule[dkey] = slotMap
		saveSlotSchedule(schedule)

		let generation = purgeSlotGenerationRecords(loadSlotGenerationRecords(), keepingDay: dkey)
		saveSlotGenerationRecords(generation)
	}

	private func checkSlotGenerationTrigger(reference date: Date = Date()) {
		let schedule = loadSlotSchedule()
		let dkey = dayKey(for: date)
		guard let slotMap = schedule[dkey] else { return }
		let currentSlot = TimeSlot.from(date: date, using: TimeZoneManager.shared.calendar)
		
		// Only check current slot, not past slots
		guard let epoch = slotMap[currentSlot.rawValue] else { return }
		let triggerDate = Date(timeIntervalSince1970: epoch)
		guard date >= triggerDate else { return }
		guard !hasGeneratedSlotTasks(currentSlot, on: date) else { return }
		
		let isLate = date.timeIntervalSince(triggerDate) > 5400
		generateTasksForSlot(currentSlot, reference: date, notify: !isLate)
	}

	private func generateTasksForSlot(_ slot: TimeSlot, reference date: Date = Date(), notify: Bool = true) {
		
		let generated = taskGenerator.generateTasks(for: slot, date: date, report: weatherReport)
		guard !generated.isEmpty else { return }
		
		// Clear uncompleted tasks from previous slots on the same day
		storage.deleteUncompletedTasks(before: slot, on: date)
		
		// Only delete tasks for the specific slot being generated (but not onboarding tasks)
		storage.deleteTasks(in: slot, on: date)
		
		storage.save(tasks: generated)
		todayTasks = storage.fetchTasks(in: slot, on: date, includeOnboarding: true)
		scheduleTaskNotifications()
		markSlotTasksGenerated(slot, on: date)
		analytics.log(event: "tasks_generated_slot", metadata: ["slot": slot.rawValue])
		
		// Only show mood capture once per slot (excluding night)
		if slot != .night && !hasLoggedMoodThisSlot && !showOnboarding {
			checkAndShowMoodCapture()
		}
		
		if notify, userStats?.notificationsEnabled == true {
			notificationService.notifyTasksUnlocked(for: slot)
		}
	}

	private var activeTaskSlots: [TimeSlot] { [.morning, .afternoon, .evening] }

	private func hasGeneratedSlotTasks(_ slot: TimeSlot, on date: Date = Date()) -> Bool {
		let map = loadSlotGenerationRecords()
		let dkey = dayKey(for: date)
		return map[dkey]?[slot.rawValue] == true
	}

	private func markSlotTasksGenerated(_ slot: TimeSlot, on date: Date = Date()) {
		let dkey = dayKey(for: date)
		var map = purgeSlotGenerationRecords(loadSlotGenerationRecords(), keepingDay: dkey)
		var slotDict = map[dkey] ?? [:]
		slotDict[slot.rawValue] = true
		map[dkey] = slotDict
		saveSlotGenerationRecords(map)
	}

	private func loadSlotSchedule() -> SlotScheduleMap {
		(UserDefaults.standard.dictionary(forKey: slotScheduleKey) as? SlotScheduleMap) ?? [:]
	}

	private func saveSlotSchedule(_ schedule: SlotScheduleMap) {
		UserDefaults.standard.set(schedule, forKey: slotScheduleKey)
	}

	private func purgeSlotSchedule(_ schedule: SlotScheduleMap, keepingDay day: String) -> SlotScheduleMap {
		var filtered: SlotScheduleMap = [:]
		if let current = schedule[day] {
			filtered[day] = current
		}
		return filtered
	}

        private func loadSlotGenerationRecords() -> SlotGenerationMap {
                (UserDefaults.standard.dictionary(forKey: slotGenerationKey) as? SlotGenerationMap) ?? [:]
        }

        private func saveSlotGenerationRecords(_ records: SlotGenerationMap) {
                UserDefaults.standard.set(records, forKey: slotGenerationKey)
        }

        private func purgeSlotGenerationRecords(_ records: SlotGenerationMap, keepingDay day: String) -> SlotGenerationMap {
                var filtered: SlotGenerationMap = [:]
                if let current = records[day] {
                        filtered[day] = current
                }
                return filtered
        }

        private func loadPenaltyRecords() -> SlotPenaltyMap {
                (UserDefaults.standard.dictionary(forKey: penaltyRecordsKey) as? SlotPenaltyMap) ?? [:]
        }

        private func savePenaltyRecords(_ records: SlotPenaltyMap) {
                UserDefaults.standard.set(records, forKey: penaltyRecordsKey)
        }

        private func purgePenaltyRecords(_ records: SlotPenaltyMap, keepingDay day: String) -> SlotPenaltyMap {
                var filtered: SlotPenaltyMap = [:]
                if let current = records[day] {
                        filtered[day] = current
                }
                return filtered
        }

	private func pettingCount(on date: Date = Date()) -> Int {
		let dict = (UserDefaults.standard.dictionary(forKey: pettingLimitKey) as? [String: Int]) ?? [:]
		return dict[dayKey(for: date)] ?? 0
	}

	private func incrementPettingCount(on date: Date = Date()) {
		let dkey = dayKey(for: date)
		var dict = (UserDefaults.standard.dictionary(forKey: pettingLimitKey) as? [String: Int]) ?? [:]
		dict = purgePettingCounts(dict, keeping: dkey)
		dict[dkey, default: 0] += 1
		UserDefaults.standard.set(dict, forKey: pettingLimitKey)
	}

	private func purgePettingCounts(_ dict: [String: Int], keeping day: String) -> [String: Int] {
		var filtered: [String: Int] = [:]
		if let value = dict[day] {
			filtered[day] = value
		}
		return filtered
	}


        private func applyDailyBondingDecayIfNeeded(reference date: Date = Date()) {
                guard let stats = userStats else { return }
                let calendar = TimeZoneManager.shared.calendar
                let lastDay = calendar.startOfDay(for: stats.lastActiveDate)
                let today = calendar.startOfDay(for: date)
		guard today > lastDay else {
			stats.lastActiveDate = date
			return
		}
		let decayDays = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
		guard decayDays > 0 else { return }
                petEngine.applyDailyDecay(days: decayDays)
                stats.lastActiveDate = date
                storage.persist()
        }

        func evaluateBondingPenalty(for slot: TimeSlot, reference date: Date = Date()) async {
                let calendar = TimeZoneManager.shared.calendar
                let dkey = dayKey(for: date)
                var penaltyRecords = purgePenaltyRecords(loadPenaltyRecords(), keepingDay: dkey)
                var slotMap = penaltyRecords[dkey] ?? [:]
                guard slotMap[slot.rawValue] != true else { return }

                let intervals = taskGenerator.scheduleIntervals(for: date)
                guard let interval = intervals[slot] else { return }

                let slotTasks = todayTasks.filter { task in
                        guard calendar.isDate(task.date, inSameDayAs: date) else { return false }
                        return interval.contains(task.date)
                }

                guard slotTasks.contains(where: { $0.status != .completed }) else { return }

			petEngine.applyLightPenalty()
                storage.persist()
                slotMap[slot.rawValue] = true
                penaltyRecords[dkey] = slotMap
                savePenaltyRecords(penaltyRecords)
                showPettingNotice("Lumio felt a bit lonely (bonding level down)")
        }

        private func elapsedTaskSlots(before slot: TimeSlot, on date: Date) -> [TimeSlot] {
                let slotIntervals = taskGenerator.scheduleIntervals(for: date)
                let now = Date()
                return slotIntervals
                        .filter { $0.value.end <= now && $0.key != slot }
                        .map { $0.key }
        }

        /// Fetch cached tasks for the latest `days` to power analytics without mutating state.
        func tasksSince(days: Int) -> [UserTask] {
                storage.fetchTasks(since: days)
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

	// Location updates are now handled on-demand via requestLocationOnce()
	// No continuous location monitoring is needed

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

		if let retained {
				retained.status = .pending
				retained.completedAt = nil
		}
		storage.deleteTasks(for: Date(), excluding: retainIDs, includeCompleted: false)
		
		// Ensure templates are loaded
		storage.bootstrapIfNeeded()
		let now = Date()
		let slot = TimeSlot.from(date: now, using: TimeZoneManager.shared.calendar)
		
		var generated = taskGenerator.generateTasks(
			for: slot,
			date: now,
			report: weatherReport,
			reservedTitles: reservedTitles
		)
		if generated.isEmpty {
			// Retry with fresh bootstrap
			storage.bootstrapIfNeeded()
			generated = taskGenerator
				.generateTasks(
					for: slot,
					date: now,
					report: weatherReport,
					reservedTitles: reservedTitles
				)
		}
		storage.save(tasks: generated)
		todayTasks = storage.fetchTasks(in: slot, on: now, includeOnboarding: true)
		scheduleTaskNotifications()
	}

	func scheduleTaskNotifications() {
		guard userStats?.notificationsEnabled == true else { return }
		Task {
			await notificationService.scheduleTaskReminders(for: todayTasks)
		}
	}

	private func refreshWeather(using location: CLLocation?) async {
		let locality = locationService.lastKnownCity
		let report = await weatherService.fetchWeather(for: location, locality: locality)
		weatherReport = report
		if !report.sunEvents.isEmpty {
			storage.saveSunEvents(report.sunEvents)
			let merged = storage.fetchSunEvents()
			sunEvents = merged
		}
		// Region is automatically updated via bindLocationUpdates() listener when locationService.lastKnownCity changes
		// Only update from weather report if location service hasn't provided a city yet
		if let city = report.locality, !(city.isEmpty), locationService.lastKnownCity.isEmpty {
			userStats?.region = city
			storage.persist()
		}
		prepareSlotGenerationSchedule(for: Date())
		checkSlotGenerationTrigger()
		
		logger.info("[AppViewModel] fetch weather: \(self.weatherReport?.currentWeather.rawValue ?? "nil"), for city: \(self.locationService.lastKnownCity)")
	}

	private func bindLocationUpdates() {
		locationService.$lastRegionComponents
			.compactMap { $0 }
			.receive(on: RunLoop.main)
			.sink { [weak self] components in
				self?.applyRegionComponents(components)
			}
			.store(in: &cancellables)
		
		// Fallback: keep legacy string updates
		locationService.$lastKnownCity
			.removeDuplicates()
			.receive(on: RunLoop.main)
			.sink { [weak self] city in
				guard let self, !city.isEmpty else { return }
				if self.userStats?.region.isEmpty == true {
					self.userStats?.region = city
					self.storage.persist()
				}
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
                // Sleep reminder 关闭后检查是否需要显示情绪记录弹窗
                if !showOnboarding {
                        checkAndShowMoodCapture()
                }
        }

	private func refreshMoodLoggingState(reference date: Date = Date()) {
		let calendar = TimeZoneManager.shared.calendar
		let currentSlot = TimeSlot.from(date: date, using: calendar)
		
		if currentSlot == .night {
			hasLoggedMoodThisSlot = false
			shouldForceMoodCapture = false
			return
		}
		
		let slotIntervals = TaskGeneratorService(storage: storage).scheduleIntervals(for: date)
		guard let interval = slotIntervals[currentSlot] else {
			hasLoggedMoodThisSlot = false
			shouldForceMoodCapture = true
			return
		}
		
		// 检查该时段是否已有记录
		let loggedThisSlot = moodEntries.contains { entry in
			entry.date >= interval.start && entry.date < interval.end
		}
		
		hasLoggedMoodThisSlot = loggedThisSlot
		shouldForceMoodCapture = !loggedThisSlot
	}

        private func snackDisplayName(for item: Item) -> String {
                if !item.assetName.isEmpty {
                        return item.assetName
                }
                return item.sku
	}
	
	// MARK: - Onboarding Completion Check
	private func checkOnboardingCompletion() {
		let onboardingTitles = [
			"Say hello to Lumio, drag up and down to play together",
			"Check out shop panel by clicking the gift box",
			"Try to refresh after all tasks are done (mark this as done first before trying)"
		]
		
		let onboardingTasks = todayTasks.filter { onboardingTitles.contains($0.title) }
		guard !onboardingTasks.isEmpty else { return }
		
		let allCompleted = onboardingTasks.allSatisfy { $0.status == .completed }
		if allCompleted && !showOnboardingCelebration {
			// Only show celebration after mood feedback is submitted
			// This will be triggered when user returns to TasksView after mood feedback
		}
	}
	
	func checkAndShowOnboardingCelebration() {
		let onboardingTitles = [
			"Say hello to Lumio, drag up and down to play together",
			"Check out shop panel by clicking the gift box",
			"Try to refresh after all tasks are done (mark this as done first before trying)"
		]
		
		let onboardingTasks = todayTasks.filter { onboardingTitles.contains($0.title) }
		guard !onboardingTasks.isEmpty else { return }
		
		let allCompleted = onboardingTasks.allSatisfy { $0.status == .completed }
		if allCompleted && !showOnboardingCelebration && pendingMoodFeedbackTask == nil {
			showOnboardingCelebration = true
		}
	}
	
	func dismissOnboardingCelebration() {
		showOnboardingCelebration = false
		// After celebration, replace onboarding tasks with current slot tasks
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		todayTasks = storage.fetchTasks(in: slot, on: Date(), includeOnboarding: false)
	}
	
	private func applyRegionComponents(_ components: RegionComponents) {
		guard let stats = userStats else { return }
		stats.regionLocality = components.locality
		stats.regionAdministrativeArea = components.administrativeArea
		stats.regionCountry = components.country
		let formatted = components.formatted
		if !formatted.isEmpty {
			stats.region = formatted
		}
		storage.persist()
	}
}


// MARK: - Slot Monitor
extension AppViewModel {
	/// - Note: 负责驱动每个时段的定时逻辑与天气刷新，不可重复启动。
	private func startSlotMonitor() {
		slotMonitorTask?.cancel()
		slotMonitorTask = Task { [weak self] in
			guard let self else { return }

			while !Task.isCancelled {
				await self.handleSlotMonitorTick()
				let interval = self.nextMonitorInterval(from: Date())
				try? await Task.sleep(for: .seconds(interval))
			}
		}
	}

	/// 触发检查
	@MainActor
	private func handleSlotMonitorTick() async {
		let currentDate = Date()
		let currentSlot = TimeSlot.from(date: currentDate, using: TimeZoneManager.shared.calendar)

		if currentSlot != lastObservedSlot {
			lastObservedSlot = currentSlot
			logger.debug("Slot changed → \(currentSlot.rawValue, privacy: .public)")
			await refreshWeather(using: locationService.lastKnownLocation)
			prepareSlotGenerationSchedule(for: currentDate)
		} else {
			prepareSlotGenerationSchedule(for: currentDate)
		}

		checkSlotGenerationTrigger(reference: currentDate)
		updateTaskRefreshEligibility(reference: currentDate)
		logger.debug("Slot tick complete for \(currentSlot.rawValue, privacy: .public)")
	}
	
	private func nextMonitorInterval(from date: Date = Date()) -> TimeInterval {
		let defaultInterval: TimeInterval = 300
		let nextBoundary = nextSlotBoundary(after: date)
		let nextTrigger = nextScheduledTrigger(after: date)
		let target = [nextBoundary, nextTrigger].compactMap { $0 }.min() ?? date.addingTimeInterval(defaultInterval)
		return max(30, target.timeIntervalSince(date))
	}
	
	private func nextSlotBoundary(after date: Date = Date()) -> Date? {
		let cal = TimeZoneManager.shared.calendar
		let todayIntervals = taskGenerator.scheduleIntervals(for: date)
		var candidates = todayIntervals.values.map(\.start).filter { $0 > date }
		if let tomorrow = cal.date(byAdding: .day, value: 1, to: date) {
			let intervals = taskGenerator.scheduleIntervals(for: tomorrow)
			candidates.append(contentsOf: intervals.values.map(\.start))
		}
		return candidates.min()
	}
	
	private func nextScheduledTrigger(after date: Date = Date()) -> Date? {
		let cal = TimeZoneManager.shared.calendar
		if let tomorrow = cal.date(byAdding: .day, value: 1, to: date) {
			prepareSlotGenerationSchedule(for: tomorrow)
		}
		let schedule = loadSlotSchedule()
		let keys = [dayKey(for: date), dayKey(for: cal.date(byAdding: .day, value: 1, to: date)!)]
		var candidates: [Date] = []
		for key in keys {
			guard let slotMap = schedule[key] else { continue }
			for epoch in slotMap.values {
				let trigger = Date(timeIntervalSince1970: epoch)
				if trigger > date {
					candidates.append(trigger)
				}
			}
		}
		return candidates.min()
	}
	
	// MARK: - Cached Data Loading
	private func loadCachedData() async {
		let fetchedSunEvents: [Date: SunTimes] = storage.fetchSunEvents()
		let fetchedShopItems: [Item] = storage.fetchShopItems()
		let fetchedInventory: [InventoryEntry] = storage.fetchInventory()

		shopItems = fetchedShopItems
		sunEvents = fetchedSunEvents
		inventory = fetchedInventory

		logger.debug("Cached data loaded: \(fetchedShopItems.count) items, \(fetchedInventory.count) inventory entries.")
	}
	
}

