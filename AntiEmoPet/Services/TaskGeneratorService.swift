import Foundation

@MainActor
final class TaskGeneratorService {
    private let storage: StorageService
    private let calendar = TimeZoneManager.shared.calendar

    init(storage: StorageService) {
        self.storage = storage
    }

	private let slotOrder: [TimeSlot] = [.morning, .afternoon, .evening]

	func generateDailyTasks(for date: Date, report: WeatherReport?, reservedTitles: Set<String> = []) -> [UserTask] {
		let templates = storage.fetchAllTaskTemplates()
		guard !templates.isEmpty else { return [] }

		let intervals = scheduleIntervals(for: date)
		var usedTitles = reservedTitles
		var tasks: [UserTask] = []

		for slot in slotOrder {
			guard let interval = intervals[slot] else { continue }
			let windows = overlappingWindows(interval: interval, report: report)
			let count = taskCount(for: windows, defaultWeather: report?.currentWeather ?? .sunny)
			guard count > 0 else { continue }

			for _ in 0..<count {
				guard let template = pickTemplate(from: templates, used: &usedTitles, windows: windows, defaultWeather: report?.currentWeather ?? .sunny) else {
					continue
				}
				let scheduled = makeSchedule(for: interval, windows: windows, defaultWeather: report?.currentWeather ?? .sunny)
				let task = UserTask(
					title: template.title,
					weatherType: scheduled.weather,
					difficulty: template.difficulty,
					category: template.category,
					energyReward: template.energyReward,
					date: scheduled.date
				)
				tasks.append(task)
			}
		}

		return tasks.sorted { $0.date < $1.date }
	}

	func generateTasks(for slot: TimeSlot, date: Date, report: WeatherReport?, reservedTitles: Set<String> = []) -> [UserTask] {
		let templates = storage.fetchAllTaskTemplates()
		guard !templates.isEmpty else { return [] }
		let intervals = scheduleIntervals(for: date)
		guard let interval = intervals[slot] else { return [] }

		let windows = overlappingWindows(interval: interval, report: report)
		let count = taskCount(for: windows, defaultWeather: report?.currentWeather ?? .sunny)
		guard count > 0 else { return [] }

		var usedTitles = reservedTitles
		var tasks: [UserTask] = []

		for _ in 0..<count {
			guard let template = pickTemplate(from: templates, used: &usedTitles, windows: windows, defaultWeather: report?.currentWeather ?? .sunny) else {
				continue
			}
			let scheduled = makeSchedule(for: interval, windows: windows, defaultWeather: report?.currentWeather ?? .sunny)
			let task = UserTask(
				title: template.title,
				weatherType: scheduled.weather,
				difficulty: template.difficulty,
				category: template.category,
				energyReward: template.energyReward,
				date: scheduled.date
			)
			tasks.append(task)
		}

		return tasks.sorted { $0.date < $1.date }
	}

	func generationTriggerTime(for slot: TimeSlot, date: Date, report: WeatherReport?) -> Date? {
		guard let interval = scheduleIntervals(for: date)[slot] else { return nil }
		let windows = overlappingWindows(interval: interval, report: report)
		let schedule = makeSchedule(for: interval, windows: windows, defaultWeather: report?.currentWeather ?? .sunny)
		return schedule.date
	}

    func makeOnboardingTasks(for date: Date) -> [UserTask] {
        let titles = [
            "Say hello to Lumio",
            "Check out shop panel",
            "Do 20 burpee"
        ]
        let baseDate = calendar.startOfDay(for: date)
        return titles.enumerated().map { index, title in
            UserTask(
                title: title,
                weatherType: .sunny,
                difficulty: .easy,
                category: .indoorDigital,
                energyReward: 6,
                date: calendar.date(byAdding: .minute, value: index * 10, to: baseDate) ?? baseDate
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
        guard let report else { return [] }
        return report.windows.filter { window in
            window.endDate > interval.start && window.startDate < interval.end
        }
    }

    private func pickTemplate(from templates: [TaskTemplate], used: inout Set<String>, windows: [WeatherWindow], defaultWeather: WeatherType) -> TaskTemplate? {
        let available = templates.filter { !used.contains($0.title) }
        guard !available.isEmpty else { return nil }

        let weather = dominantWeather(in: windows) ?? defaultWeather
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
        let window = preferredWindow(in: windows) ?? WeatherWindow(startDate: interval.start, endDate: interval.end, weather: defaultWeather)
        let start = max(window.startDate, interval.start)
        let end = min(window.endDate, interval.end)
        let duration = max(60, end.timeIntervalSince(start))
        let randomOffset = Double.random(in: 0..<duration)
        let tentative = start.addingTimeInterval(randomOffset)
        let date = min(tentative, interval.end)
        return (date, window.weather)
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
        case .cloudy: return 3
        case .windy: return 2
        case .snowy: return 2
        case .rainy: return 1
        }
    }

    private func categoryWeights(for weather: WeatherType) -> [TaskCategory: Int] {
        switch weather {
        case .sunny:
            return [.outdoor: 6, .indoorDigital: 3, .indoorActivity: 4, .socials: 4, .petCare: 3]
        case .cloudy:
            return [.outdoor: 2, .indoorDigital: 4, .indoorActivity: 4, .socials: 3, .petCare: 3]
        case .rainy:
            return [.indoorDigital: 5, .indoorActivity: 4, .socials: 3, .petCare: 4]
        case .snowy:
            return [.outdoor: 1, .indoorDigital: 4, .indoorActivity: 5, .socials: 3, .petCare: 3]
        case .windy:
            return [.outdoor: 2, .indoorDigital: 4, .indoorActivity: 4, .socials: 3, .petCare: 3]
        }
    }

    private func taskCount(for windows: [WeatherWindow], defaultWeather: WeatherType) -> Int {
        let weather = dominantWeather(in: windows) ?? defaultWeather
        let baseRange: [Int]
        switch weather {
        case .sunny:
            baseRange = [3, 3, 2, 1]
        case .cloudy:
            baseRange = [1, 2, 2]
        case .rainy:
            baseRange = [1, 1, 2]
        case .snowy:
            baseRange = [1, 2, 2]
        case .windy:
            baseRange = [1, 2, 3]
        }
        return baseRange.randomElement() ?? 1
    }
}
