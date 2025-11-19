import Foundation
import Combine

@MainActor
final class EnergyStatisticsViewModel: ObservableObject {
	@Published var energySummary: EnergySummary = .empty

	init() {
		self.energySummary = .empty
	}

	struct EnergySummary {
		let todayAdd: Int
		let averageDailyAddPastWeek: Int
		let todayTaskCount: Int
		let averageDailyTaskCountPastWeek: Double
		let trend: TrendDirection
		let comment: String
		let taskTypeCounts: [TaskCategory: Int]
		let dailyEnergyAdds: [Date: Int]

		static let empty = EnergySummary(
			todayAdd: 0,
			averageDailyAddPastWeek: 0,
			todayTaskCount: 0,
			averageDailyTaskCountPastWeek: 0,
			trend: .flat,
			comment: "",
			taskTypeCounts: [:],
			dailyEnergyAdds: [:]
		)
	}

	// MARK: - Main Calculation
        func energySummary(
                metrics: [DailyActivityMetrics]? = nil,
                tasks: [UserTask] = [],
                days: Int = 7
        ) -> EnergySummary? {
                guard !tasks.isEmpty else { return nil }

                let calendar = TimeZoneManager.shared.calendar
                let now = Date()
                let startDate = calendar.startOfDay(
                        for: calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: now)!
                )

#if DEBUG
                let completed = tasks.filter { $0.status == .completed }
                let missingTimestamps = completed.filter { $0.completedAt == nil }
                if !missingTimestamps.isEmpty {
                        print("⚠️ Completed tasks missing timestamps: \(missingTimestamps.map { $0.id })")
                }
                print("[EnergySummary] tasks=\(tasks.count), completed=\(completed.count), windowDays=\(days)")
#endif

                let dailyEnergyAdds = calculateDailyEnergy(from: tasks, since: startDate, days: days)
                let todayAdd = dailyEnergyAdds[calendar.startOfDay(for: now)] ?? 0

		let averageAddWeek = {
			guard !dailyEnergyAdds.isEmpty else { return 0 }
			let total = dailyEnergyAdds.values.reduce(0, +)
			let divisor = min(days, max(1, dailyEnergyAdds.count))
			return Int(Double(total) / Double(divisor))
		}()

		var todayTaskCount = 0
		var averageTaskCountWeek: Double = 0
		if let metrics {
			let result = calculateTaskMetrics(metrics, since: startDate, days: days)
			todayTaskCount = result.today
			averageTaskCountWeek = result.average
		}

		let trend = calculateTrend(from: metrics, and: dailyEnergyAdds)
		let comment = generateComment(for: trend, metrics: metrics, days: days)
		let taskTypeCounts = taskCategoryCompletionRatio(tasks: tasks)
		
#if DEBUG
for task in tasks {
	print("TASK:", task.id, task.status, task.completedAt ?? "nil", task.energyReward)
}
print("Daily Energy Adds:", dailyEnergyAdds)
print("Today Add:", todayAdd)
print("Avg Week:", averageAddWeek)
print("StartDate:", startDate)
print("Calendar:", calendar.timeZone)
print("Today key:", calendar.startOfDay(for: now))
#endif

		return EnergySummary(
			todayAdd: todayAdd,
			averageDailyAddPastWeek: averageAddWeek,
			todayTaskCount: todayTaskCount,
			averageDailyTaskCountPastWeek: averageTaskCountWeek,
			trend: trend,
			comment: comment,
			taskTypeCounts: taskTypeCounts,
			dailyEnergyAdds: dailyEnergyAdds
		)
	}

	// MARK: - Subfunctions

	/// 每日任务能量 (sum by day)
	private func calculateDailyEnergy(from tasks: [UserTask], since startDate: Date, days: Int) -> [Date: Int] {
		let calendar = TimeZoneManager.shared.calendar
		var energyPerDay: [Date: Int] = [:]

		for task in tasks {
			guard task.status == .completed, let completedAt = task.completedAt else { continue }
			let day = calendar.startOfDay(for: completedAt)
			if completedAt >= startDate {
				energyPerDay[day, default: 0] += task.energyReward
			}
		}

		// 限定最多取最近 N 天
		let sortedKeys = energyPerDay.keys.sorted(by: <)
		let limitedKeys = Array(sortedKeys.suffix(days))
		return Dictionary(uniqueKeysWithValues: limitedKeys.map { ($0, energyPerDay[$0] ?? 0) })
	}

	/// 任务指标：今日任务数 + 平均任务数
	private func calculateTaskMetrics(_ metrics: [DailyActivityMetrics], since startDate: Date, days: Int) -> (today: Int, average: Double) {
		let calendar = TimeZoneManager.shared.calendar
		let now = Date()

		let today = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: now) })?.completedTaskCount ?? 0
		let weekMetrics = metrics.filter { $0.date >= startDate }
		let recordedDays = Set(weekMetrics.map { calendar.startOfDay(for: $0.date) }).count
		let divisor = min(days, max(1, recordedDays))
		let totalTasksWeek = weekMetrics.reduce(0) { $0 + $1.completedTaskCount }
		let average = Double(totalTasksWeek) / Double(divisor)

		return (today, average)
	}

	/// 趋势计算
	private func calculateTrend(from metrics: [DailyActivityMetrics]?, and taskEnergyPerDay: [Date: Int]) -> TrendDirection {
		guard let metrics else { return .flat }
		let calendar = TimeZoneManager.shared.calendar
		let metricsByDay = Dictionary(uniqueKeysWithValues: metrics.map { (calendar.startOfDay(for: $0.date), $0) })

		let daysSorted = Array(taskEnergyPerDay.keys).sorted()
		let midpoint = daysSorted.count / 2
		var firstHalfTasks = 0
		var secondHalfTasks = 0
		var firstHalfInteractions = 0
		var secondHalfInteractions = 0

		for (index, day) in daysSorted.enumerated() {
			guard let metric = metricsByDay[day] else { continue }
			if index < midpoint {
				firstHalfTasks += metric.completedTaskCount
				firstHalfInteractions += metric.petInteractionCount
			} else {
				secondHalfTasks += metric.completedTaskCount
				secondHalfInteractions += metric.petInteractionCount
			}
		}

		var score = 0
		if secondHalfTasks > firstHalfTasks { score += 1 }
		else if secondHalfTasks < firstHalfTasks { score -= 1 }
		if secondHalfInteractions > firstHalfInteractions { score += 1 }
		else if secondHalfInteractions < firstHalfInteractions { score -= 1 }

		return score > 0 ? .up : (score < 0 ? .down : .flat)
	}

	/// 文案
	private func generateComment(for trend: TrendDirection, metrics: [DailyActivityMetrics]?, days: Int) -> String {
		var parts: [String] = []
		if let metrics {
			let totalTasks = metrics.reduce(0) { $0 + $1.completedTaskCount }
			let totalInteractions = metrics.reduce(0) { $0 + $1.petInteractionCount }
			parts.append("You've completed \(totalTasks) tasks and interacted with Lumio \(totalInteractions) times in \(days) days.")
		}

		switch trend {
		case .up:
			parts.append("You've done great job recently!")
		case .down:
			parts.append("You came less these days, the energy pod is drying. Try to complete more tasks and interact with Lumio more often!")
		case .flat:
			parts.append("Your routine is being established. Keep going!")
		}

		return parts.joined(separator: "\n")
	}

	/// 任务类别完成统计
	func taskCategoryCompletionRatio(tasks: [UserTask]) -> [TaskCategory: Int] {
		let completed = tasks.filter { $0.status == .completed }
		var counts: [TaskCategory: Int] = [:]
		for task in completed {
			counts[task.category, default: 0] += 1
		}
		return counts
	}
}
