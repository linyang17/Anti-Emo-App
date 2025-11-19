import Foundation
import SwiftUI
import SwiftData
import Combine
import CoreLocation
import UIKit


@MainActor
final class AppViewModel: ObservableObject {
	@Published var todayTasks: [UserTask] = [] {
		didSet {
			updateTaskRefreshEligibility()
		}
	}
	@Published var pet: Pet? {didSet {petEngine.updatePetReference(pet) }}
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
	@Published var showMoodCapture = false
	@Published var shouldForceMoodCapture = false
	@Published var pendingMoodFeedbackTask: UserTask?
	@Published private(set) var canRefreshCurrentSlot = false
	@Published private(set) var hasUsedRefreshThisSlot = false
	@Published var pettingNotice: String?
	lazy var petEngine = PetEngine(pet: nil)

		let locationService = LocationService()
		private let storage: StorageService
		private let taskGenerator: TaskGeneratorService
		private let rewardEngine = RewardEngine()
		private let notificationService = NotificationService()
		private let weatherService = WeatherService()
		private let analytics = AnalyticsService()
		private var cancellables: Set<AnyCancellable> = []
		private let sleepReminderService = SleepReminderService()
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

	var totalEnergy: Int {
		userStats?.totalEnergy ?? 0
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

                // 优先使用上次缓存的城市填充用户信息，避免 Profile 中城市为空
			let cachedCity = locationService.lastKnownCity
			if !cachedCity.isEmpty, userStats?.region.isEmpty == true {
				userStats?.region = cachedCity
			}
			
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

		shopItems = storage.fetchShopItems()

                moodEntries = storage.fetchMoodEntries()
                refreshMoodLoggingState()
                sunEvents = storage.fetchSunEvents()
                inventory = storage.fetchInventory()

                todayTasks = storage.fetchTasks(for: .now)
                applyDailyBondingDecayIfNeeded()

                // Always fetch weather on app open (even if location sharing is off, use cached location)
                if let stats = userStats, stats.shareLocationAndWeather {
                        beginLocationUpdates()
                        _ = await requestWeatherAccess()
                        locationService.requestLocationOnce()
                } else {
                        // Still try to fetch weather using last known location for mood/task recording
                        locationService.requestLocationOnce()
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
                prepareSlotGenerationSchedule(for: Date())
                checkSlotGenerationTrigger()
                startSlotMonitor()

                showOnboarding = !(userStats?.Onboard ?? false)

                // 检查是否需要显示情绪记录弹窗（在 onboarding 和 sleep reminder 之后）
                if !showOnboarding && !showSleepReminder {
                        checkAndShowMoodCapture()
                }

                isLoading = false

                dailyMetricsCache = makeDailyActivityMetrics(days: 7)
                recordMoodOnLaunch()
        }

        /// 检查今天是否已记录情绪，如果没有则显示弹窗
        func checkAndShowMoodCapture() {
			guard !hasLoggedMoodToday else {
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
        }
	
	func refreshIfNeeded() async {
		await load()
		// 重新检查是否需要显示情绪记录弹窗（可能在后台时日期变化了）
		if !showOnboarding && !showSleepReminder {
			checkAndShowMoodCapture()
		}
	}

	func refreshCurrentSlotTasks(retaining retained: UserTask? = nil) async {
		guard canRefreshCurrentSlot else { return }
		await evaluateBondingPenalty(for: TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar))
		await refreshTasks(retaining: retained)
		markCurrentSlotRefreshed()
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		markSlotTasksGenerated(slot, on: Date())
		updateTaskRefreshEligibility()
		prepareSlotGenerationSchedule(for: Date())
		checkSlotGenerationTrigger()
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
		guard let stats = userStats, task.status != .completed else { return }
		
		// 检查是否可以完成:pending直接完成,或者已达到buffer时间
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

		// 随机掉落一份 snack 奖励
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
		todayTasks = storage.fetchTasks(for: .now)
		
		// 触发强制情绪反馈弹窗
		pendingMoodFeedbackTask = task
	}
	
        /// 提交任务完成后的情绪反馈
        /// - Parameters:
        ///   - delta: 情绪变化值 (-5: 更差, 0: 无变化, +5: 更好, +10: 好很多)
        ///   - task: 完成的任务
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
		
		analytics.log(event: "mood_feedback_after_task", metadata: [
			"delta": "\(delta)",
			"category": task.rawValue,
			"weather": weather.rawValue
		])
		
		// 清除待处理的反馈任务
		pendingMoodFeedbackTask = nil
	}
	

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
		showPettingNotice(remaining > 0 ? "Played with Lumio, \(remaining)/\(maxcount) left" : "You've played with Lumio today")
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
		// PRD requirement: Purchase decor -> Bonding +10, XP +10
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
		// Onboarding 完成后检查是否需要显示情绪记录弹窗
		if !showSleepReminder {
			checkAndShowMoodCapture()
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
	private func showPettingNotice(_ message: String) {
		pettingNoticeTask?.cancel()
		pettingNotice = message
		pettingNoticeTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 2_000_000_000)
			pettingNotice = nil
		}
	}

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
			relatedWeather: relatedWeather ?? weatherReport?.currentWeather
		)
		storage.saveMoodEntry(entry)
		moodEntries = storage.fetchMoodEntries()
		
                // 刷新今日情绪记录状态
                refreshMoodLoggingState()

                // 如果是应用打开时的记录,关闭强制弹窗
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

	private func startSlotMonitor() {
		slotMonitorTask?.cancel()
		slotMonitorTask = Task { [weak self] in
			guard let self else { return }
			while !Task.isCancelled {
				try? await Task.sleep(for: .seconds(60))
				await self.handleSlotMonitorTick()
			}
		}
	}

	@MainActor
	private func handleSlotMonitorTick() async {
		let currentSlot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)

		if currentSlot != lastObservedSlot {
			lastObservedSlot = currentSlot
			await refreshWeather(using: locationService.lastKnownLocation)
		}

		prepareSlotGenerationSchedule(for: Date())
		checkSlotGenerationTrigger()
		updateTaskRefreshEligibility()
	}

	private func checkSlotGenerationTrigger(reference date: Date = Date()) {
		let schedule = loadSlotSchedule()
		let dkey = dayKey(for: date)
		guard let slotMap = schedule[dkey] else { return }
		for slot in activeTaskSlots {
			guard let epoch = slotMap[slot.rawValue] else { continue }
			let triggerDate = Date(timeIntervalSince1970: epoch)
			guard date >= triggerDate else { continue }
			guard !hasGeneratedSlotTasks(slot, on: date) else { continue }
			generateTasksForSlot(slot, reference: date)
		}
	}

	private func generateTasksForSlot(_ slot: TimeSlot, reference date: Date = Date()) {
		let generated = taskGenerator.generateTasks(for: slot, date: date, report: weatherReport)
		guard !generated.isEmpty else { return }
		storage.deleteTasks(in: slot, on: date)
		storage.save(tasks: generated)
		todayTasks = storage.fetchTasks(for: .now)
		scheduleTaskNotifications()
		markSlotTasksGenerated(slot, on: date)
		analytics.log(event: "tasks_generated_slot", metadata: ["slot": slot.rawValue])
		if userStats?.notificationsEnabled == true {
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
		
		// Always fetch fresh weather before generating tasks
		if let stats = userStats, stats.shareLocationAndWeather {
			beginLocationUpdates()
			locationService.requestLocationOnce()
		}
		await refreshWeather(using: locationService.lastKnownLocation)
		
		storage.resetAllCompletionDates()
		if let retained {
			retained.status = .pending
			retained.completedAt = nil
		}
		storage.resetCompletionDates(for: Date())
		storage.deleteTasks(for: Date(), excluding: retainIDs)
		
		// Ensure templates are loaded
		storage.bootstrapIfNeeded()
		
		var generated = taskGenerator.generateDailyTasks(for: Date(), report: weatherReport, reservedTitles: reservedTitles)
		if generated.isEmpty {
			// Retry with fresh bootstrap
			storage.bootstrapIfNeeded()
			generated = taskGenerator.generateDailyTasks(for: Date(), report: weatherReport, reservedTitles: reservedTitles)
		}
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
		prepareSlotGenerationSchedule(for: Date())
		checkSlotGenerationTrigger()
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
                // Sleep reminder 关闭后检查是否需要显示情绪记录弹窗
                if !showOnboarding {
                        checkAndShowMoodCapture()
                }
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

        private func snackDisplayName(for item: Item) -> String {
                if !item.assetName.isEmpty {
                        return item.assetName
                }
                return item.sku
	}
}
