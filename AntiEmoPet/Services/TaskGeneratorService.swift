import Foundation

@MainActor
final class TaskGeneratorService {
	private let storage: StorageService
	private let calendar = TimeZoneManager.shared.calendar
	private let useRandomizedTime: Bool

	init(storage: StorageService, randomizeTime: Bool = false) {
		self.storage = storage
		self.useRandomizedTime = randomizeTime
	}

	func generationTriggerTime(for slot: TimeSlot, date: Date, report: WeatherReport?) -> Date? {
		guard let interval = scheduleIntervals(for: date)[slot] else { return nil }
		
		if useRandomizedTime {
			// Pick the best contiguous window (at WeatherKit granularity) within this slot interval,
			// then pick a random time inside that window.
			let windows = overlappingWindows(interval: interval, report: report)
			let defaultWeather = report?.currentWeather ?? .cloudy
			let bestWindow = bestContiguousWindow(in: windows, clippedTo: interval, fallback: defaultWeather)
			return randomDate(in: bestWindow)
		} else {
			// 固定时间
			switch slot {
			case .morning:   return calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)
			case .afternoon: return calendar.date(bySettingHour: 14, minute: 0, second: 0, of: date)
			case .evening:   return calendar.date(bySettingHour: 18, minute: 30, second: 0, of: date)
			default: return nil
			}
		}
	}

	private let slotOrder: [TimeSlot] = [.morning, .afternoon, .evening]

	func generateTasks(for slot: TimeSlot, date: Date, report: WeatherReport?, reservedTitles: Set<String> = []) -> [UserTask] {
		let templates = storage.fetchAllTaskTemplates()
		guard !templates.isEmpty else { return [] }
		let intervals = scheduleIntervals(for: date)
		guard let interval = intervals[slot] else { return [] }

		let windows = overlappingWindows(interval: interval, report: report)
		// Always generate exactly 3 tasks
		let count = 3

		var usedTitles = reservedTitles
		var tasks: [UserTask] = []

		for _ in 0..<count {
			guard let template = pickTemplate(from: templates, used: &usedTitles, windows: windows, defaultWeather: report?.currentWeather ?? .sunny) else {
				continue
			}
			let scheduled = makeSchedule(for: interval, windows: windows, defaultWeather: report?.currentWeather ?? .sunny)
			let sunEvent = report?.sunEvents
			let dayLength = dayLengthMinutes(for: date, sunEvents: sunEvent)
			let task = UserTask(
				title: template.title,
				weatherType: scheduled.weather,
				category: template.category,
				energyReward: template.energyReward,
				date: scheduled.date,
				relatedDayLength: dayLength
			)
			tasks.append(task)
		}

		return tasks.sorted { $0.date < $1.date }
	}


	func makeOnboardingTasks(for date: Date, weather: WeatherType, dayLen: Int) -> [UserTask] {
		let titles = [
			"Say hello to Lumio, drag up and down to play together",
			"Check out shop panel by clicking the gift box",
			"Try to refresh after all tasks are done (mark this as done first before trying)"
		]
		let baseDate = calendar.startOfDay(for: date)
		return titles.enumerated().map { index, title in
			UserTask(
				title: title,
				weatherType: weather,
				category: .indoorDigital,
				energyReward: 5,
				date: calendar.date(byAdding: .minute, value: index * 10, to: baseDate) ?? baseDate,
				relatedDayLength: dayLen,
				isOnboarding: true
			)
		}
	}

	func scheduleIntervals(for date: Date) -> [TimeSlot: DateInterval] {
		let startOfDay = calendar.startOfDay(for: date)
		let slotStartHours: [(TimeSlot, Int)] = [(.morning, 6), (.afternoon, 12), (.evening, 17)]
		var intervals: [TimeSlot: DateInterval] = [:]

		for (index, pair) in slotStartHours.enumerated() {
			let (slot, hour) = pair
			guard let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay) else { continue }
			let endHour: Int
			if index + 1 < slotStartHours.count {
				endHour = slotStartHours[index + 1].1
			} else {
				endHour = 22
			}
			let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay) ?? start.addingTimeInterval(5 * 3_600)
			intervals[slot] = DateInterval(start: start, end: end)
		}
		return intervals
	}

	private func overlappingWindows(interval: DateInterval, report: WeatherReport?) -> [WeatherWindow] {
		guard let report else {
			 // Fallback: create a single window with default sunny weather
			 return [WeatherWindow(startDate: interval.start, endDate: interval.end, weather: .sunny)]
		}
		let windows = report.windows.filter { window in
			window.endDate > interval.start && window.startDate < interval.end
		}
		
		// If filtering resulted in no windows (e.g. report coverage issue), fallback
		if windows.isEmpty {
			 return [WeatherWindow(startDate: interval.start, endDate: interval.end, weather: report.currentWeather)]
		}
		
		return windows
	}

	private func pickTemplate(from templates: [TaskTemplate], used: inout Set<String>, windows: [WeatherWindow], defaultWeather: WeatherType) -> TaskTemplate? {
		let weather = dominantWeather(in: windows) ?? defaultWeather
		let available = templates.filter { template in
			guard !used.contains(template.title) else { return false }
			return template.category.isEligible(for: weather)
		}
		guard !available.isEmpty else { return nil }

		let weights = categoryWeights(for: weather)
		let grouped = Dictionary(grouping: available, by: \TaskTemplate.category)
		let weightedCategories: [TaskCategory] = grouped.compactMap { category, templates -> [TaskCategory] in
			let weight = max(1, weights[category] ?? 1)
			return Array(repeating: category, count: weight)
		}.flatMap { $0 }

		let chosenCategory = weightedCategories.randomElement() ?? grouped.keys.randomElement() ?? .indoorDigital
		let options = grouped[chosenCategory] ?? available
		guard let template = options.randomElement() else { return nil }
		used.insert(template.title)
		return template
	}

	private func makeSchedule(for interval: DateInterval, windows: [WeatherWindow], defaultWeather: WeatherType) -> (date: Date, weather: WeatherType) {
		let bestWindow = bestContiguousWindow(in: windows, clippedTo: interval, fallback: defaultWeather)
		let date = randomDate(in: bestWindow)
		return (date, bestWindow.weather)
	}

	/// Selects the best contiguous weather window inside `interval` using the existing WeatherKit window granularity.
	/// Rules: higher priority weather wins; if tied, longer duration wins; if tied, earlier start wins.
	/// Implementation notes (perf):
	/// - Clips windows to the slot interval
	/// - Sorts once by start
	/// - Merges adjacent/overlapping windows of the same weather in a single pass
	private func bestContiguousWindow(in windows: [WeatherWindow], clippedTo interval: DateInterval, fallback: WeatherType) -> WeatherWindow {
		// Clip to interval and discard empty intersections
		var clipped: [WeatherWindow] = []
		clipped.reserveCapacity(windows.count)

		for w in windows {
			let start = max(w.startDate, interval.start)
			let end = min(w.endDate, interval.end)
			if end > start {
				clipped.append(WeatherWindow(startDate: start, endDate: end, weather: w.weather))
			}
		}

		guard !clipped.isEmpty else {
			return WeatherWindow(startDate: interval.start, endDate: interval.end, weather: fallback)
		}

		clipped.sort { $0.startDate < $1.startDate }

		// Merge adjacent/overlapping windows with same weather.
		// WeatherKit windows usually abut exactly; allow a small tolerance for safe merging.
		let gapTolerance: TimeInterval = 60
		var merged: [WeatherWindow] = []
		merged.reserveCapacity(clipped.count)

		for w in clipped {
			if let last = merged.last,
			   last.weather == w.weather,
			   w.startDate.timeIntervalSince(last.endDate) <= gapTolerance {
				merged[merged.count - 1] = WeatherWindow(
					startDate: last.startDate,
					endDate: max(last.endDate, w.endDate),
					weather: last.weather
				)
			} else {
				merged.append(w)
			}
		}

		// Pick best by priority, then duration, then earliest start
		var best = merged[0]
		var bestPriority = priority(for: best.weather)
		var bestDuration = best.endDate.timeIntervalSince(best.startDate)

		if merged.count > 1 {
			for w in merged.dropFirst() {
				let p = priority(for: w.weather)
				if p > bestPriority {
					best = w
					bestPriority = p
					bestDuration = w.endDate.timeIntervalSince(w.startDate)
					continue
				}
				if p == bestPriority {
					let d = w.endDate.timeIntervalSince(w.startDate)
					if d > bestDuration {
						best = w
						bestDuration = d
						continue
					}
					if d == bestDuration, w.startDate < best.startDate {
						best = w
						// duration/priority unchanged
					}
				}
			}
		}

		return best
	}

	/// Picks a random Date inside the given window. If the window is invalid, returns its start.
	private func randomDate(in window: WeatherWindow) -> Date {
		let start = window.startDate
		let end = window.endDate
		guard end > start else { return start }
		return start.addingTimeInterval(Double.random(in: 0..<(end.timeIntervalSince(start))))
	}

	private func preferredWindow(in windows: [WeatherWindow]) -> WeatherWindow? {
		let sorted = windows.sorted { lhs, rhs in
			priority(for: lhs.weather) > priority(for: rhs.weather)
		}
		return sorted.first
	}

	private func dominantWeather(in windows: [WeatherWindow]) -> WeatherType? {
		guard !windows.isEmpty else { return nil }
		return windows.max { lhs, rhs in
			priority(for: lhs.weather) < priority(for: rhs.weather)
		}?.weather
	}

	private func priority(for weather: WeatherType) -> Int {
		switch weather {
		case .sunny: return 5
		case .cloudy: return 4
		case .windy: return 2
		case .snowy: return 3
		case .rainy: return 1
		}
	}

	private func categoryWeights(for weather: WeatherType) -> [TaskCategory: Int] {
		switch weather {
		case .sunny:
			return [.outdoor: 6, .indoorDigital: 1, .indoorActivity: 1, .socials: 1, .petCare: 1, .physical: 4]
		case .cloudy:
			return [.outdoor: 6, .indoorDigital: 1, .indoorActivity: 2, .socials: 2, .petCare: 1, .physical: 6]
		case .rainy:
			return [.indoorDigital: 5, .indoorActivity: 4, .socials: 4, .petCare: 4, .physical: 4]
		case .snowy:
			return [.outdoor: 2, .indoorDigital: 4, .indoorActivity: 5, .socials: 6, .petCare: 2, .physical: 4]
		case .windy:
			return [.outdoor: 3, .indoorDigital: 4, .indoorActivity: 4, .socials: 4, .petCare: 2, .physical: 4]
		}
	}

	// 不同天气生成不同数量的任务
	private func taskCount(for windows: [WeatherWindow], defaultWeather: WeatherType) -> Int {
		let weather = dominantWeather(in: windows) ?? defaultWeather
		let baseRange: [Int]
		switch weather {
		case .sunny:
			baseRange = [4, 3, 3, 2]
		case .cloudy:
			baseRange = [4, 3, 3, 3]
		case .rainy:
			baseRange = [3, 2]
		case .snowy:
			baseRange = [3, 2, 2]
		case .windy:
			baseRange = [3, 3, 2]
		}
		return baseRange.randomElement() ?? 1
	}
}
