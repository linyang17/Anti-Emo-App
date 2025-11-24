import Foundation
import SwiftData
import OSLog

@MainActor
final class StorageService {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.Lumio.pet", category: "StorageService")

    init(context: ModelContext) {
        self.context = context
    }

    func bootstrapIfNeeded() {
        do {
            var didInsert = false
            didInsert = try ensureSeed(for: Pet.self, create: { [Pet(name: "Lumio")] }) || didInsert
            didInsert = try ensureSeed(for: UserStats.self, create: {
                [UserStats(gender: GenderIdentity.unspecified.rawValue, birthday: nil)]
            }) || didInsert
            didInsert = try ensureItems() || didInsert
            didInsert = try ensureTaskTemplates() || didInsert
            if didInsert { saveContext(reason: "bootstrap seeds") }
        } catch {
            logger.error("Failed to bootstrap seeds: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchPet() -> Pet? {
        do {
            if try ensureSeed(for: Pet.self, create: { [Pet(name: "Lumio")] }) {
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
            if try ensureSeed(for: UserStats.self, create: {
                [UserStats(gender: GenderIdentity.unspecified.rawValue, birthday: nil)]
            }) {
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

	func fetchTemplates() -> [TaskTemplate] {
		do {
			if try ensureTaskTemplates() {
				saveContext(reason: "ensure template seeds")
			}
			let descriptor = FetchDescriptor<TaskTemplate>(
				sortBy: [SortDescriptor(\TaskTemplate.title, order: .forward)]
			)
			return try context.fetch(descriptor)
		} catch {
			logger.error("Failed to fetch templates: \(error.localizedDescription, privacy: .public)")
			return []
		}
	}

    func fetchTasks(for date: Date) -> [UserTask] {
        do {
            let calendar = TimeZoneManager.shared.calendar
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

			let predicate = #Predicate<UserTask> { task in
				task.date >= start && task.date < end
			}

			let descriptor = FetchDescriptor<UserTask>(
				predicate: predicate,
				sortBy: [SortDescriptor(\UserTask.date, order: .forward)]
			)
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch tasks: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Fetch tasks from the recent N days (inclusive of today).
    func fetchTasks(since days: Int, excludingCompleted: Bool = false) -> [UserTask] {
        let calendar = TimeZoneManager.shared.calendar
        let now = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: now) ?? now)

        do {
            let completed = TaskStatus.completed
            let predicate: Predicate<UserTask>
            if excludingCompleted {
                predicate = #Predicate<UserTask> { task in
                    task.date >= start && task.status != completed
                }
            } else {
                predicate = #Predicate<UserTask> { task in
                    task.date >= start
                }
            }

            let descriptor = FetchDescriptor<UserTask>(
                predicate: predicate,
                sortBy: [SortDescriptor(\UserTask.date, order: .forward)]
            )
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch recent tasks: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func save(tasks: [UserTask]) {
        guard !tasks.isEmpty else { return }
        tasks.forEach { context.insert($0) }
        saveContext(reason: "save tasks")
    }

    func deleteTasks(for date: Date, excluding ids: Set<UUID> = [], includeCompleted: Bool = true) {
        do {
            let calendar = TimeZoneManager.shared.calendar
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let predicate = #Predicate<UserTask> {
                $0.date >= start && $0.date < end
            }
            let descriptor = FetchDescriptor<UserTask>(predicate: predicate)
            let fetched = try context.fetch(descriptor)
            let targets = fetched.filter { !ids.contains($0.id) }
            let filtered = includeCompleted ? targets : targets.filter { $0.status != .completed }
            filtered.forEach { context.delete($0) }
            guard !filtered.isEmpty else { return }
            saveContext(reason: "delete tasks")
        } catch {
            logger.error("Failed to delete tasks: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resetCompletionDates(for date: Date) {
        do {
            let calendar = TimeZoneManager.shared.calendar
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
            let predicate = #Predicate<UserTask> { task in
                task.date >= start && task.date < end
            }
            let descriptor = FetchDescriptor<UserTask>(predicate: predicate)
            let targets = try context.fetch(descriptor)
            targets.forEach { $0.completedAt = nil }
            saveContext(reason: "reset completion dates")
        } catch {
            logger.error("Failed to reset completion dates: \(error.localizedDescription, privacy: .public)")
        }
    }

    func resetAllCompletionDates() {
        do {
            let descriptor = FetchDescriptor<UserTask>()
            let targets = try context.fetch(descriptor)
            guard !targets.isEmpty else { return }
            targets.forEach { $0.completedAt = nil }
            saveContext(reason: "reset all completion dates")
        } catch {
            logger.error("Failed to reset all completion dates: \(error.localizedDescription, privacy: .public)")
        }
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

	func fetchSunEvents(limit: Int = 60) -> [Date: SunTimes] {
		do {
			var descriptor = FetchDescriptor<SunTimesRecord>(
				sortBy: [SortDescriptor(\SunTimesRecord.day, order: .reverse)]
			)
			descriptor.fetchLimit = limit
			let records = try context.fetch(descriptor)
			let calendar = TimeZoneManager.shared.calendar
			var result: [Date: SunTimes] = [:]
			for record in records {
				let day = calendar.startOfDay(for: record.day)
				result[day] = SunTimes(sunrise: record.sunrise, sunset: record.sunset)
			}
			return result
		} catch {
			logger.error("Failed to fetch sun events: \(error.localizedDescription, privacy: .public)")
			return [:]
		}
	}

	func saveSunEvents(_ events: [Date: SunTimes], keepLatest limit: Int = 90) {
		guard !events.isEmpty else { return }
		let calendar = TimeZoneManager.shared.calendar
		var didMutate = false
		do {
			for (rawDay, sun) in events {
				let day = calendar.startOfDay(for: rawDay)
				let predicate = #Predicate<SunTimesRecord> { $0.day == day }
				var descriptor = FetchDescriptor<SunTimesRecord>(predicate: predicate)
				descriptor.fetchLimit = 1
				if let existing = try context.fetch(descriptor).first {
					if existing.sunrise != sun.sunrise || existing.sunset != sun.sunset {
						existing.sunrise = sun.sunrise
						existing.sunset = sun.sunset
						existing.updatedAt = Date()
						didMutate = true
					}
				} else {
					let record = SunTimesRecord(day: day, sunrise: sun.sunrise, sunset: sun.sunset)
					context.insert(record)
					didMutate = true
				}
			}
			if didMutate {
				trimSunEvents(keeping: limit)
				saveContext(reason: "save sun events")
			}
		} catch {
			logger.error("Failed to save sun events: \(error.localizedDescription, privacy: .public)")
		}
	}

    func deleteUncompletedTasks(before slot: TimeSlot, on date: Date) {
        guard let currentSlotInterval = slotInterval(for: slot, on: date) else { return }
        let startOfDay = TimeZoneManager.shared.calendar.startOfDay(for: date)
        
        let start = startOfDay
        let end = currentSlotInterval.start
        do {
            let completedStatus = TaskStatus.completed
            let predicate = #Predicate<UserTask> { task in
                task.date >= start && task.date < end && task.status != completedStatus
            }
            
            let descriptor = FetchDescriptor<UserTask>(predicate: predicate)
            let tasksToDelete = try context.fetch(descriptor)
            
            guard !tasksToDelete.isEmpty else { return }
            tasksToDelete.forEach { context.delete($0) }
            saveContext(reason: "delete uncompleted tasks before slot \(slot.rawValue)")
            logger.info("Deleted \(tasksToDelete.count) uncompleted tasks before slot \(slot.rawValue)")
        } catch {
            logger.error("Failed to delete uncompleted tasks: \(error.localizedDescription, privacy: .public)")
        }
    }

    func deleteTasks(in slot: TimeSlot, on date: Date) {
		guard let interval = slotInterval(for: slot, on: date) else { return }
		let start = interval.start
		let end = interval.end
		do {
			let predicate = #Predicate<UserTask> { task in
				task.date >= start && task.date < end
			}
			let descriptor = FetchDescriptor<UserTask>(predicate: predicate)
			let targets = try context.fetch(descriptor)
			guard !targets.isEmpty else { return }
			targets.forEach { context.delete($0) }
			saveContext(reason: "delete tasks in slot \(slot.rawValue)")
		} catch {
			logger.error("Failed to delete tasks in slot \(slot.rawValue): \(error.localizedDescription, privacy: .public)")
		}
	}

	private func slotInterval(for slot: TimeSlot, on date: Date) -> DateInterval? {
		let calendar = TimeZoneManager.shared.calendar
		let startOfDay = calendar.startOfDay(for: date)
		let startHour: Int
		let endHour: Int
		switch slot {
		case .morning:
			startHour = 6
			endHour = 12
		case .afternoon:
			startHour = 12
			endHour = 17
		case .evening:
			startHour = 17
			endHour = 22
		case .night:
			startHour = 22
			endHour = 24
		}
		guard let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: startOfDay) else { return nil }
		let end: Date
		if endHour == 24 {
			end = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? start.addingTimeInterval(8 * 3_600)
		} else {
			end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay) ?? start.addingTimeInterval(5 * 3_600)
		}
		return DateInterval(start: start, end: end)
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
    
    // MARK: - SunTimes Persistence
    /// 保存日照时间数据（用于统计分析）
    func saveSunTimes(_ sunTimes: [Date: SunTimes]) {
        guard let data = try? JSONEncoder().encode(SunTimesSnapshot(sunTimes: sunTimes)) else {
            logger.error("Failed to encode sun times")
            return
        }
        UserDefaults.standard.set(data, forKey: "cached_sun_times")
        logger.info("Saved \(sunTimes.count) sun time entries")
    }
    
    /// 获取缓存的日照时间数据
    func fetchSunTimes() -> [Date: SunTimes] {
        guard let data = UserDefaults.standard.data(forKey: "cached_sun_times"),
              let snapshot = try? JSONDecoder().decode(SunTimesSnapshot.self, from: data) else {
            return [:]
        }
        return snapshot.toDictionary()
    }
    
    /// 更新指定日期的日照时间
    func updateSunTime(for date: Date, sunTimes: SunTimes) {
        var current = fetchSunTimes()
        let calendar = TimeZoneManager.shared.calendar
        let day = calendar.startOfDay(for: date)
        current[day] = sunTimes
        saveSunTimes(current)
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
        let seeds = DefaultSeeds.makeItems(logger: existing.isEmpty ? logger : nil)
        let missing = seeds.filter { !existingSKUs.contains($0.sku) }
        missing.forEach { context.insert($0) }
        return !missing.isEmpty
    }

    @discardableResult
    private func ensureTaskTemplates() throws -> Bool {
        let descriptor = FetchDescriptor<TaskTemplate>()
        let existing = try context.fetch(descriptor)
        let seeds = DefaultSeeds.makeTaskTemplates(logger: existing.isEmpty ? logger : nil)
        let needsReset = existing.count != seeds.count || existing.contains { $0.energyReward <= 0 }
        if needsReset {
            existing.forEach { context.delete($0) }
            seeds.forEach { context.insert($0) }
            return true
        }
        return false
    }

    private func saveContext(reason: String) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context during \(reason, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

	private func trimSunEvents(keeping limit: Int) {
		guard limit > 0 else { return }
		do {
			let descriptor = FetchDescriptor<SunTimesRecord>(
				sortBy: [SortDescriptor(\SunTimesRecord.day, order: .reverse)]
			)
			let records = try context.fetch(descriptor)
			guard records.count > limit else { return }
			for record in records.dropFirst(limit) {
				context.delete(record)
			}
		} catch {
			logger.error("Failed to trim sun events: \(error.localizedDescription, privacy: .public)")
		}
	}
}

// MARK: - SunTimes Persistence Helper
struct SunTimesSnapshot: Codable {
    let entries: [SunTimesEntry]
    
    init(sunTimes: [Date: SunTimes]) {
        entries = sunTimes.map { SunTimesEntry(date: $0.key, sunrise: $0.value.sunrise, sunset: $0.value.sunset) }
    }
    
    func toDictionary() -> [Date: SunTimes] {
        Dictionary(uniqueKeysWithValues: entries.map { entry in
            (entry.date, SunTimes(sunrise: entry.sunrise, sunset: entry.sunset))
        })
    }
    
    struct SunTimesEntry: Codable {
        let date: Date
        let sunrise: Date
        let sunset: Date
    }
}

enum DefaultSeeds {
    private struct ItemSeed: Decodable {
        let sku: String
        let type: ItemType
        let assetName: String
        let costEnergy: Int
        let bondingBoost: Int
    }

    private struct TaskTemplateSeed: Decodable {
        let title: String
        let isOutdoor: Bool
        let category: TaskCategory
        let energyReward: Int
    }

	private struct ItemSeedContainer: Decodable {
		let version: Int
		let items: [ItemSeed]
	}
	
	private struct TaskTemplateSeedContainer: Decodable {
		let version: Int
		let templates: [TaskTemplateSeed]
	}


        private static var cachedItems: [Item]?

        static func makeItems(logger: Logger? = nil) -> [Item] {
                if let cachedItems { return cachedItems }

                do {
                        guard let url = Bundle.main.url(forResource: "items", withExtension: "json") else {
                                logger?.error("❌ items.json not found in app bundle.")
                                return []
                        }

                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase

                        let container = try decoder.decode(ItemSeedContainer.self, from: data)

                        let items = container.items.map { seed in
                                Item(
                                        sku: seed.sku,
                                        type: seed.type,
                                        assetName: seed.assetName,
                                        costEnergy: seed.costEnergy,
                                        bondingBoost: seed.bondingBoost
                                )
                        }

                        cachedItems = items
                        logger?.info("✅ Loaded \(items.count) items from items.json (version \(container.version))")
                        return items
                } catch {
                        logger?.error("❌ Failed to load or decode items.json: \(error.localizedDescription, privacy: .public)")
                        return []
                }
        }

	
        private static var cachedTemplates: [TaskTemplate]?

        static func makeTaskTemplates(logger: Logger? = nil) -> [TaskTemplate] {
                if let cachedTemplates { return cachedTemplates }

                do {
                        guard let url = Bundle.main.url(forResource: "task_templates", withExtension: "json") else {
                                logger?.error("❌ task_templates.json not found in app bundle.")
                                return []
                        }

                        let data = try Data(contentsOf: url)
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase

                        let container = try decoder.decode(TaskTemplateSeedContainer.self, from: data)

                        let templates: [TaskTemplate] = container.templates.compactMap { seed in
                                guard let category = TaskCategory(rawValue: seed.category.rawValue) else {
                                        logger?.warning("⚠️ Unknown task category: \(seed.category.rawValue, privacy: .public)")
                                        return nil
                                }
                                return TaskTemplate(
                                        title: seed.title.trimmingCharacters(in: .whitespacesAndNewlines),
                                        isOutdoor: seed.isOutdoor,
                                        category: category,
                                        energyReward: max(1, seed.energyReward)
                                )
                        }

                        cachedTemplates = templates
                        logger?.info("✅ Loaded \(templates.count) task templates (version \(container.version))")
                        UserDefaults.standard.set(container.version, forKey: "TaskTemplateDataVersion")

                        return templates

                } catch let DecodingError.dataCorrupted(context) {
                        logger?.error("❌ JSON data corrupted: \(context.debugDescription, privacy: .public)")
                        return []
                } catch let DecodingError.keyNotFound(key, context) {
                        logger?.error("❌ Missing key '\(key.stringValue, privacy: .public)' in JSON: \(context.debugDescription, privacy: .public)")
                        return []
                } catch let DecodingError.typeMismatch(type, context) {
                        logger?.error("❌ Type mismatch for \(type, privacy: .public): \(context.debugDescription, privacy: .public)")
                        return []
                } catch {
                        logger?.error("❌ Failed to load or decode task_templates.json: \(error.localizedDescription, privacy: .public)")
                        return []
                }
        }
}

