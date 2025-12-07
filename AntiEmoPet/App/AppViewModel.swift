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
	@Published var energyEvents: [EnergyEvent] = []
	@Published var inventory: [InventoryEntry] = []
	@Published var dailyMetricsCache: [DailyActivityMetrics] = []
        @Published var showSleepReminder = false
        @Published var rewardBanner: RewardEvent?
        @Published var currentLanguage: String = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "en"
        @Published var shouldShowNotificationSettingsPrompt = false
        @Published var slotNotificationPreferences: [TimeSlot: Bool] = [:]
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
	var taskGenerator: TaskGeneratorService
	private let rewardEngine = RewardEngine()
	private let notificationService = NotificationService()
	private let weatherService = WeatherService()
	private let analytics = AnalyticsService()
	private let aggregationService = DataAggregationService()
	private let uploadService = DataUploadService()
	private var historyExporter = HistoryExportService()
	private var cancellables: Set<AnyCancellable> = []
	private let sleepReminderService = SleepReminderService()
	private let logger = Logger(subsystem: "com.Lumio.pet", category: "AppViewModel")
	private let refreshRecordsKey = "taskRefreshRecords"
        private let slotScheduleKey = "taskSlotSchedule"
        private let slotGenerationKey = "taskSlotGenerationRecords"
        private let penaltyRecordsKey = "taskSlotPenaltyRecords"
        private let pettingLimitKey = "dailyPettingLimit"
        private let slotNotificationPreferenceKey = "slotNotificationPreferences"
        private let streakAwardedKey = "streak.lastAwardedDay"
        private var lastObservedSlot: TimeSlot?
	private var isLoadingData = false
	private var awaitingLocationWeatherRefresh = false
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

	// New private property added as per instructions
	private var pendingGenerationConfigUpdate = false

        // MARK: - Initialization
        init(modelContext: ModelContext) {
                storage = StorageService(context: modelContext)
                taskGenerator = TaskGeneratorService(storage: storage)
                slotNotificationPreferences = loadSlotNotificationPreferences()
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
                showOnboarding = !(userStats?.isOnboard ?? false)
		isLoading = false
	}
	
        /// Full load for users who have completed onboarding
        func load() async {
                if isLoadingData { return }
                isLoadingData = true
                defer { isLoadingData = false }
                logger.info("Loading app data…")

                storage.bootstrapIfNeeded()
				pet = storage.fetchPet()
				userStats = storage.fetchStats()
                self.taskGenerator = TaskGeneratorService(storage: storage, randomizeTime: self.userStats?.randomizeTaskTime ?? false)

		await loadCachedData()
		
		scheduleTaskNotifications()
		
		// onboarding阶段没有数据缓存
                showOnboarding = !(userStats?.isOnboard ?? false)
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
                let storedEnergyHistory = storage.fetchEnergyHistory()
                if !storedEnergyHistory.isEmpty {
                        energyHistory = storedEnergyHistory
                } else if let data = UserDefaults.standard.data(forKey: "energyHistory"),
                          let decoded = try? JSONDecoder().decode([EnergyHistoryEntry].self, from: data) {
                        energyHistory = decoded
                        decoded.forEach { storage.addEnergyHistoryEntry($0) }
                }

                energyEvents = storage.fetchEnergyEvents()

		if userStats?.shareLocationAndWeather == true {
				_ = await requestWeatherAccess()
				_ = await locationService.requestLocationOnce()
		}

                await refreshWeather(using: locationService.lastKnownLocation)

                startSlotMonitor()

                await queuePreviousDaySummaryIfNeeded(reference: Date())
                await uploadService.processQueue(sharingEnabled: userStats?.shareLocationAndWeather ?? false)

                // Check sleep reminder and mood capture
                if !showSleepReminder {
                        checkAndShowMoodCapture()
                }

		isLoading = false
		dailyMetricsCache = makeDailyActivityMetrics(days: 7)
                if userStats!.totalDays > 1 {
                        applyDailyBondingDecayIfNeeded()
                }
		recordMoodOnLaunch()
		
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		self.refreshDisplayedTasks(for: slot, on: Date())
		
	}
	
        private func fetchInitialWeather() async {
                        // Request location once when app opens
                if let stats = userStats, stats.shareLocationAndWeather {
                        let granted = await requestWeatherAccess()
                        if granted {
                                awaitingLocationWeatherRefresh = locationService.lastKnownLocation == nil
                                _ = await locationService.requestLocationOnce()
                        }
                }
                if !awaitingLocationWeatherRefresh {
                        await refreshWeather(using: locationService.lastKnownLocation)
                }
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
			refreshDisplayedTasks(for: slot, on: Date())
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
		refreshDisplayedTasks(for: slot, on: Date())
		
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
				refreshDisplayedTasks(for: slot, on: Date())
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
		
                let rewards = rewardEngine.applyTaskReward(for: task, stats: stats, catalog: shopItems)
                petEngine.handleAction(.taskComplete)   // award bonding + xp

                if rewards.energy > 0 {
                        recordEnergyEvent(delta: rewards.energy, relatedTask: task)
                }

                var snackName: String?
                if let snack = rewards.snack {
                        incrementInventory(for: snack)
                        snackName = snackDisplayName(for: snack)
                        analytics.log(event: "snack_reward", metadata: ["sku": snack.sku])
                }

                analytics.log(event: "task_completed", metadata: ["title": task.title])
                let slot = TimeSlot.from(date: task.date, using: TimeZoneManager.shared.calendar)
                incrementTaskCompletion(for: Date(), timeSlot: slot)
                updateStreakIfEligible(for: slot, on: task.date)
                rewardBanner = RewardEvent(energy: rewards.energy, xp: 1, snackName: snackName)
                logTodayEnergySnapshot()
                dailyMetricsCache = makeDailyActivityMetrics()
		storage.persist()
		refreshDisplayedTasks(for: slot, on: Date())
				
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
		petEngine.handleAction(.pat)
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
		petEngine.applyPurchaseReward(xpGain: 10, bondingBoost: item.bondingBoost)
		
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
                isOnboard: Bool
        ) async {
                userStats?.nickname = sanitizedNickname(nickname)
		
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
                userStats?.isOnboard = isOnboard
		
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
                                self.rescheduleSlotUnlocks()
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
			storage.addInventory(forSKU: item.sku)
			let updatedInventory = storage.fetchInventory()
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
                // Check inventory quantity first
                if let entry = inventory.first(where: { $0.sku == sku }), entry.quantity > 0,
                   let item = shopItems.first(where: { $0.sku == sku }) {
                        storage.decrementInventory(forSKU: sku)
                        inventory = storage.fetchInventory()
                        if item.type == .snack {
                                petEngine.handleAction(.snackFeed)
                                rewardBanner = RewardEvent(energy: 0, xp: 1)
                        } else {
                                petEngine.handleAction(.feed(item: item))
                        }
                        storage.persist()
                        analytics.log(event: "item_used", metadata: ["sku": sku])
                        logTodayEnergySnapshot()
                        return true
                } else {
                        return false
                }
        }

        @discardableResult
        func feedSnack(_ item: Item) -> Bool {
                guard item.type == .snack else { return false }
                guard let entry = inventory.first(where: { $0.sku == item.sku }), entry.quantity > 0 else { return false }

                storage.decrementInventory(forSKU: item.sku)
                inventory = storage.fetchInventory()
                petEngine.handleAction(.snackFeed)
                rewardBanner = RewardEvent(energy: 0, xp: 1)
                storage.persist()
                analytics.log(event: "snack_fed", metadata: ["sku": item.sku])

                return true
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
                storage.addEnergyHistoryEntry(entry)
                energyHistory = storage.fetchEnergyHistory()
        }

        func updateSlotNotificationPreference(_ slot: TimeSlot, enabled: Bool) {
                slotNotificationPreferences[slot] = enabled
                persistSlotNotificationPreferences(slotNotificationPreferences)
                rescheduleSlotUnlocks()
                scheduleTaskNotifications()
        }

        func updateAllSlotNotifications(enabled: Bool) {
                for slot in activeTaskSlots { slotNotificationPreferences[slot] = enabled }
                persistSlotNotificationPreferences(slotNotificationPreferences)
                rescheduleSlotUnlocks()
                scheduleTaskNotifications()
        }

        private func rescheduleSlotUnlocks(reference date: Date = Date()) {
                guard userStats?.notificationsEnabled == true else { return }
                notificationService.scheduleSlotUnlocks(for: slotSchedule(for: date), allowedSlots: enabledNotificationSlots)
        }

        private func recordEnergyEvent(delta: Int, relatedTask: UserTask) {
                guard delta > 0 else { return }
                let event = EnergyEvent(delta: delta, relatedTaskId: relatedTask.id)
                storage.addEnergyEvent(event)
                energyEvents = storage.fetchEnergyEvents()
        }

	private var interactionsKey: String { "dailyPetInteractions" }
	private var timeSlotKey: String { "dailyTaskTimeSlots" }

        private func dayKey(for date: Date) -> String {
                let cal = TimeZoneManager.shared.calendar
                let day = cal.startOfDay(for: date)
                return isoDayFormatter.string(from: day)
        }

        private func loadSlotNotificationPreferences() -> [TimeSlot: Bool] {
                let stored = (UserDefaults.standard.dictionary(forKey: slotNotificationPreferenceKey) as? [String: Bool]) ?? [:]
                var merged: [TimeSlot: Bool] = Dictionary(uniqueKeysWithValues: activeTaskSlots.map { ($0, true) })

                for (rawKey, value) in stored {
                        if let slot = TimeSlot(rawValue: rawKey) {
                                merged[slot] = value
                        }
                }
                return merged
        }

        private func persistSlotNotificationPreferences(_ preferences: [TimeSlot: Bool]) {
                let raw = Dictionary(uniqueKeysWithValues: preferences.map { ($0.rawValue, $1) })
                UserDefaults.standard.set(raw, forKey: slotNotificationPreferenceKey)
        }

        private var enabledNotificationSlots: Set<TimeSlot> {
                Set(slotNotificationPreferences.filter { $0.value }.keys)
        }

        private func sanitizedNickname(_ raw: String) -> String {
                let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                let filtered = String(trimmed.unicodeScalars.filter { allowed.contains($0) })
                return String(filtered.prefix(30))
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

        private func updateStreakIfEligible(for slot: TimeSlot, on date: Date) {
                guard let stats = userStats else { return }
                let dkey = dayKey(for: date)
                guard UserDefaults.standard.string(forKey: streakAwardedKey) != dkey else { return }

                let calendar = TimeZoneManager.shared.calendar
                let tasks = storage.fetchTasks(in: slot, on: date, includeOnboarding: false)
                guard !tasks.isEmpty else { return }
                let completed = tasks.allSatisfy { $0.status == .completed }
                guard completed else { return }

                stats.totalDays += 1
                stats.lastActiveDate = calendar.startOfDay(for: date)
                UserDefaults.standard.set(dkey, forKey: streakAwardedKey)
                analytics.log(event: "streak_up", metadata: ["streak": "\(stats.totalDays)", "slot": slot.rawValue])
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

        // MARK: - Slot Schedule Preparation
        /// 确保当天任务时段生成调度表存在。仅在跨日或首次启动时生成，防止重复重建。
        private func ensureSlotScheduleExists(for date: Date, slot: TimeSlot? = nil) {
                let dkey = dayKey(for: date)
                var schedule = loadSlotSchedule()

                schedule = purgeSlotSchedule(schedule, keepingDay: dkey)

                var slotMap: [String: Double] = schedule[dkey] ?? [:]
                let slots = slot.map { [$0] } ?? activeTaskSlots
                for slot in slots {
                        if slotMap[slot.rawValue] == nil {
                                if let trigger = taskGenerator.generationTriggerTime(for: slot, date: date, report: weatherReport) {
                                        slotMap[slot.rawValue] = trigger.timeIntervalSince1970
                                }
                        }
                }
                let readableSchedule = scheduleFormatter(slotmap: slotMap)
                schedule[dkey] = slotMap
                saveSlotSchedule(schedule)
                logger.info("[Schedule] Schedule prepared for \(dkey): \(readableSchedule)")

                rescheduleSlotUnlocks(reference: date)

                // 清理旧的生成记录，仅保留当天
                let generation = purgeSlotGenerationRecords(loadSlotGenerationRecords(), keepingDay: dkey)
                saveSlotGenerationRecords(generation)
        }

        private func slotSchedule(for date: Date = Date()) -> [TimeSlot: Date] {
                let dkey = dayKey(for: date)
                let schedule = loadSlotSchedule()
                guard let slotMap = schedule[dkey] else { return [:] }
                return Dictionary(uniqueKeysWithValues: slotMap.compactMap { raw, epoch in
                        guard let slot = TimeSlot(rawValue: raw) else { return nil }
                        return (slot, Date(timeIntervalSince1970: epoch))
                })
        }
	
	private func scheduleFormatter(slotmap: [String: Double]) -> [String: String] {
		
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "HH:mm:ss"
		dateFormatter.timeZone = .current
		
		let readableSchedule = slotmap.mapValues { epoch -> String in
			let date = Date(timeIntervalSince1970: epoch)
			return dateFormatter.string(from: date)
		}
		return readableSchedule
	}
	

        private func checkSlotGenerationTrigger(reference date: Date = Date()) {
                let schedule = loadSlotSchedule()
                let dkey = dayKey(for: date)
                guard let slotMap = schedule[dkey] else { return }
                _ = scheduleFormatter(slotmap: slotMap)

                let pendingSlots: [(TimeSlot, Date)] = slotMap.compactMap { raw, epoch in
                        guard let slot = TimeSlot(rawValue: raw) else { return nil }
                        return (slot, Date(timeIntervalSince1970: epoch))
                }
                .sorted { $0.1 < $1.1 }

                for (slot, triggerDate) in pendingSlots where date >= triggerDate && !hasGeneratedSlotTasks(slot, on: date) {
                        logger.info("[checkSlotGenerationTrigger]: generating \(slot.rawValue) because trigger passed at \(triggerDate)")
                        generateTasksForSlot(slot, reference: date, notify: shouldNotify(for: slot))
                }
        }

        private func generateTasksForSlot(_ slot: TimeSlot, reference date: Date = Date(), notify: Bool = true) {
                // 检查当前时段是否已有任务。如果有任务就只打印日志，不再继续生成；如果没有，则执行删除旧任务 + 新任务生成的流程。
                let existingTasks = storage.fetchTasks(in: slot, on: date, includeOnboarding: false)

                logger.info("[AppViewModel] generateTasksForSlot: preparing \(slot.rawValue) at \(date)")

                guard existingTasks.isEmpty else {
                        logger.info("[AppViewModel] fetchTasks: \(slot.rawValue) slot already has \(existingTasks.count) tasks. Skipping generation.")
                        markSlotTasksGenerated(slot, on: date)
                        scheduleTaskNotifications()
                        refreshDisplayedTasks(for: slot, on: date)
                        return
                }
		
            storage.archiveUncompletedTasks(before: slot, on: date)

		let generated = taskGenerator.generateTasks(for: slot, date: date, report: weatherReport)
		guard !generated.isEmpty else {
			logger.warning("[AppViewModel] generateTasksForSlot: no tasks generated for slot \(slot.rawValue).")
			return
		}

                storage.save(tasks: generated)

                refreshDisplayedTasks(for: slot, on: date)
                markSlotTasksGenerated(slot, on: date)

                if notify, shouldNotify(for: slot) {
                                notificationService.notifyTasksUnlocked(for: slot, allowedSlots: enabledNotificationSlots)
                }
                scheduleTaskNotifications()
                analytics.log(event: "tasks_generated_slot", metadata: ["slot": slot.rawValue])
                logger.info("[AppViewModel] generateTasksForSlot: \(generated.count) new tasks generated for \(slot.rawValue)")

		if slot != .night && !hasLoggedMoodThisSlot && !showOnboarding {
			checkAndShowMoodCapture()
		}
        }

        private var activeTaskSlots: [TimeSlot] { [.morning, .afternoon, .evening] }

        private func shouldNotify(for slot: TimeSlot) -> Bool {
                guard userStats?.notificationsEnabled == true else { return false }
                return slotNotificationPreferences[slot] ?? true
        }
	
	// New helper method inserted as per instructions
	private func refreshDisplayedTasks(for slot: TimeSlot, on date: Date) {
	    // Always base onboarding visibility on today's onboarding tasks
	    let todayAll = storage.fetchTasks(for: date)
	    let onboardingTasks = todayAll.filter { $0.isOnboarding }
	    if !onboardingTasks.isEmpty {
	        let allCompleted = onboardingTasks.allSatisfy { $0.status == .completed }
	        if allCompleted && !showOnboardingCelebration {
	            // Trigger celebration as soon as all onboarding tasks complete
	            checkAndShowOnboardingCelebration()
	        }
	        // Show onboarding tasks until the celebration is shown (and while it's visible)
	        if !allCompleted || showOnboardingCelebration {
	            todayTasks = onboardingTasks.sorted { $0.date < $1.date }
	            return
	        }
	    }

            // Otherwise, show current slot tasks (non-onboarding)
            let slotTasks = storage.fetchTasks(in: slot, on: date, includeOnboarding: false)
            if slotTasks.isEmpty, !hasGeneratedSlotTasks(slot, on: date), let previous = previousSlot(for: slot) {
                    let previousSlotTasks = storage.fetchTasks(in: previous, on: date, includeOnboarding: false)
                    if !previousSlotTasks.isEmpty {
                            todayTasks = previousSlotTasks
                            return
                    }
            }
            todayTasks = slotTasks
        }

        private func previousSlot(for slot: TimeSlot) -> TimeSlot? {
                switch slot {
                case .morning: return .night
                case .afternoon: return .morning
                case .evening: return .afternoon
                case .night: return .evening
                }
        }

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


        func evaluateBondingPenalty(for slot: TimeSlot, reference date: Date = Date()) async {
                return
        }

	
        func applyDailyBondingDecayIfNeeded(reference date: Date = Date()) {
            let cal = TimeZoneManager.shared.calendar
			let todayStart = cal.startOfDay(for: .now)

            // Guard: only run after local midnight and once per day
            let stampKey = "bondingPenalty.lastEvaluatedDay"
            let todayStamp = dayKey(for: todayStart)
            if UserDefaults.standard.string(forKey: stampKey) == todayStamp { return }
			guard .now >= todayStart else { return }

            // Evaluate yesterday's completion
            let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            let tasks = storage.fetchTasks(for: yesterday, includeArchived: true, includeOnboarding: false)
            let didComplete = tasks.contains { $0.status == .completed }
            if !didComplete {
				petEngine.handleAction(.penalty)
                storage.persist()
                showPettingNotice("Lumio felt a bit lonely (bonding level down)")
            }

            UserDefaults.standard.set(todayStamp, forKey: stampKey)
        }

        private func elapsedTaskSlots(before slot: TimeSlot, on date: Date) -> [TimeSlot] {
                let slotIntervals = taskGenerator.scheduleIntervals(for: date)
                let now = Date()
                return slotIntervals
                        .filter { $0.value.end <= now && $0.key != slot }
                        .map { $0.key }
        }

        /// Fetch cached tasks for the latest `days` to power analytics without mutating state.
        func tasksSince(days: Int, includeArchived: Bool = true, includeOnboarding: Bool = false) -> [UserTask] {
                storage.fetchTasks(since: days, includeArchived: includeArchived, includeOnboarding: includeOnboarding)
        }

        func taskHistorySections(days: Int = 30) -> [TaskHistorySection] {
                let cal = TimeZoneManager.shared.calendar
                let tasks = storage.fetchTasks(since: days, includeArchived: true, includeOnboarding: false)
                let grouped = Dictionary(grouping: tasks) { cal.startOfDay(for: $0.date) }
                return grouped.keys
                        .sorted(by: >)
                        .map { day in
                                TaskHistorySection(date: day, tasks: grouped[day]?.sorted { $0.date < $1.date } ?? [])
                        }
        }

        func exportTaskHistory(days: Int = 30) -> URL? {
                let range = historyRange(forDays: days)
                let tasks = storage.fetchTasks(since: days, includeArchived: true, includeOnboarding: false)
                let moods = moodEntries.filter { range.contains($0.date) }
                let events = energyEvents.filter { range.contains($0.date) }
                return try? historyExporter.export(tasks: tasks, moods: moods, energyEvents: events, range: range)
        }

        func importTaskHistory(from url: URL) -> Bool {
                do {
                        let export = try historyExporter.importHistory(from: url)
                        storage.importHistory(export)
                        moodEntries = storage.fetchMoodEntries()
                        energyEvents = storage.fetchEnergyEvents()
                        dailyMetricsCache = makeDailyActivityMetrics()

                        let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
                        todayTasks = storage.fetchTasks(in: slot, on: Date())
                        return true
                } catch {
                        logger.error("Failed to import history: \(error.localizedDescription, privacy: .public)")
                        return false
                }
        }

        private func historyRange(forDays days: Int) -> ClosedRange<Date> {
                let cal = TimeZoneManager.shared.calendar
                let now = Date()
                let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(1, days) - 1), to: now) ?? now)
                return start...now
        }

        private func queuePreviousDaySummaryIfNeeded(reference: Date = Date()) async {
                guard let stats = userStats else { return }
                let cal = TimeZoneManager.shared.calendar
                let todayStart = cal.startOfDay(for: reference)
                let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
                let queuedKey = "summaryUpload.lastQueuedDay"
                let yesterdayKey = dayKey(for: yesterday)

                guard UserDefaults.standard.string(forKey: queuedKey) != yesterdayKey else { return }

                let tasks = storage.fetchTasks(for: yesterday, includeArchived: true, includeOnboarding: false)
                let moods = storage.fetchMoodEntries().filter { cal.isDate($0.date, inSameDayAs: yesterday) }
                let summaries = aggregationService.aggregate(
                        userId: stats.id.uuidString,
                        region: stats.region,
                        date: yesterday,
                        moodEntries: moods,
                        tasks: tasks,
                        sunEvents: sunEvents
                )

                uploadService.enqueue(date: yesterday, summaries: summaries)
                UserDefaults.standard.set(yesterdayKey, forKey: queuedKey)
                await uploadService.processQueue(sharingEnabled: stats.shareLocationAndWeather)
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
                storage.archiveTasks(for: Date(), excluding: retainIDs, includeCompleted: false)
		
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
		refreshDisplayedTasks(for: slot, on: now)
		scheduleTaskNotifications()
	}

        func scheduleTaskNotifications() {
                guard userStats?.notificationsEnabled == true else { return }
                Task {
                        await notificationService.scheduleTaskReminders(for: todayTasks, allowedSlots: enabledNotificationSlots)
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
		
		if let city = report.locality, !(city.isEmpty), locationService.lastKnownCity.isEmpty {
			userStats?.region = city
			storage.persist()
		}
		
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

	func checkAndShowOnboardingCelebration() {
	    // Must have onboarding tasks today
	    let todayTasksAll = storage.fetchTasks(for: Date())
	    let onboardingTasks = todayTasksAll.filter { $0.isOnboarding }
	    guard !onboardingTasks.isEmpty else { return }
	    
	    // Check if celebration already shown once per user
	    if let stats = userStats, stats.hasShownOnboardingCelebration {
	        return
	    }

	    // All onboarding tasks must be completed
	    let allCompleted = onboardingTasks.allSatisfy { $0.status == .completed }
	    guard allCompleted else { return }

	    // No pending mood feedback or visible reward banner
	    guard pendingMoodFeedbackTask == nil else { return }
	    guard rewardBanner == nil else { return }

	    // Only show if not already showing
	    if !showOnboardingCelebration {
	        showOnboardingCelebration = true
	    }
	}
	
	func dismissOnboardingCelebration() {
		showOnboardingCelebration = false
		// Persist one-time flag
		userStats?.hasShownOnboardingCelebration = true
		storage.persist()
		// After celebration, remove today's onboarding tasks and show current slot tasks
		let slot = TimeSlot.from(date: Date(), using: TimeZoneManager.shared.calendar)
		storage.deleteOnboardingTasks(for: Date())
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
                        TimeZoneManager.shared.updateTimeZone(forRegion: formatted)
                }
                storage.persist()
        }

        // MARK: - Task generation config change handler
        func applyTaskGenerationSettingsChanged() {
			let useRandom = self.userStats?.randomizeTaskTime ?? false
			
			// Rebuild generator immediately with the latest setting
			self.taskGenerator = TaskGeneratorService(storage: self.storage, randomizeTime: useRandom)
			self.pendingGenerationConfigUpdate = false
			
			// Reset and rebuild today's schedule so remaining slots use the new configuration
			let now = Date()
			let todayKey = dayKey(for: now)
			var schedule = loadSlotSchedule()
			schedule[todayKey] = [:]
			saveSlotSchedule(schedule)
			
			// Create a fresh schedule and re-evaluate triggers for today
			ensureSlotScheduleExists(for: now)
			checkSlotGenerationTrigger(reference: now)
        }
	
	/// Public method to force-regenerate current slot tasks after settings change
	func regenerateCurrentSlotTasks() {
		let now = Date()
		let slot = TimeSlot.from(date: now, using: TimeZoneManager.shared.calendar)
		// Delete non-onboarding tasks in current slot to allow fresh generation
                storage.archiveTasks(in: slot, on: now)
		// Trigger generation flow based on current schedule/generator
		generateTasksForSlot(slot, reference: now, notify: false)
	}
}



// MARK: - Slot Monitor
extension AppViewModel {
	
	/// 每个时段的定时逻辑与天气刷新，自动检测跨日并生成当天 schedule。
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

	/// 每个时段定时触发检查，驱动任务生成与刷新逻辑。
	@MainActor
	private func handleSlotMonitorTick() async {
		let currentDate = Date()
		let calendar = TimeZoneManager.shared.calendar
		let currentSlot = TimeSlot.from(date: currentDate, using: calendar)
		let currentDayKey = dayKey(for: currentDate)

		// 检查是否跨日（dayKey变更）
		let lastDayKey = UserDefaults.standard.string(forKey: "lastObservedDayKey")
		if lastDayKey != currentDayKey {
			logger.info("Detected day change → generating new schedule for \(currentDayKey)")
			ensureSlotScheduleExists(for: currentDate)
			await queuePreviousDaySummaryIfNeeded(reference: currentDate)
			UserDefaults.standard.set(currentDayKey, forKey: "lastObservedDayKey")
		}

		// Changed block as per instructions
		if currentSlot != lastObservedSlot {
			lastObservedSlot = currentSlot
			logger.debug("Slot changed → \(currentSlot.rawValue, privacy: .public)")

			if pendingGenerationConfigUpdate {
				// Rebuild generator with the latest setting at the boundary of the new slot
				self.taskGenerator = TaskGeneratorService(storage: self.storage, randomizeTime: self.userStats?.randomizeTaskTime ?? false)

				// Reset today's schedule so remaining slots use the new generator configuration
				let todayKey = dayKey(for: currentDate)
				var schedule = loadSlotSchedule()
				schedule[todayKey] = [:]
				saveSlotSchedule(schedule)

				pendingGenerationConfigUpdate = false
			}
                }

		// 检查当前 slot 是否应触发任务生成
		checkSlotGenerationTrigger(reference: currentDate)
		updateTaskRefreshEligibility(reference: currentDate)

		logger.trace("Slot tick complete for \(currentSlot.rawValue, privacy: .public)")
	}

	/// 计算下一个监控时间点（只考虑当天）
	private func nextMonitorInterval(from date: Date = Date()) -> TimeInterval {
		let defaultInterval: TimeInterval = 60*10 // fallback 10分钟
		let nextBoundary = nextSlotBoundary(after: date)
		let nextTrigger = nextScheduledTrigger(after: date)
		let target = [nextBoundary, nextTrigger].compactMap { $0 }.min() ?? date.addingTimeInterval(defaultInterval)
		return target.timeIntervalSince(date)
	}

	
	private func nextSlotBoundary(after date: Date = Date()) -> Date? {
		let intervals = taskGenerator.scheduleIntervals(for: date)
		let candidates = intervals.values.map(\.start).filter { $0 > date }
		return candidates.min()
	}

	
        private func nextScheduledTrigger(after date: Date = Date()) -> Date? {
                let todayKey = dayKey(for: date)
                let schedule = loadSlotSchedule()
                let generated = loadSlotGenerationRecords()[todayKey] ?? [:]
                guard let slotMap = schedule[todayKey] else { return nil }

                let candidates = slotMap.compactMap { raw, epoch -> Date? in
                        guard generated[raw] != true else { return nil }
                        let trigger = Date(timeIntervalSince1970: epoch)
                        return trigger > date ? trigger : nil
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

struct TaskHistorySection: Identifiable {
        var id: Date { date }
        let date: Date
        let tasks: [UserTask]
}

