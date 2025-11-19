import Foundation
import Combine

@MainActor
final class EnergyStatisticsViewModel: ObservableObject {
	@Published var energySummary: EnergySummary = .empty

	init() {
		self.energySummary = .empty
	}
	
    struct EnergySummary {
        let lastEnergy: Int
        let delta: Int
        let todayAdd: Int
        let todayDeduct: Int
        let todayDelta: Int
        let averageDailyAddPastWeek: Int
        let averageDailyUsePastWeek: Int
        let averageToday: Int
        let averagePastWeek: Int
        let todayTaskCount: Int
        let averageDailyTaskCountPastWeek: Double
        let trend: TrendDirection
        let comment: String
        let taskTypeCounts: [TaskCategory: Int]

        static let empty = EnergySummary(
            lastEnergy: 0,
            delta: 0,
            todayAdd: 0,
            todayDeduct: 0,
            todayDelta: 0,
            averageDailyAddPastWeek: 0,
            averageDailyUsePastWeek: 0,
            averageToday: 0,
            averagePastWeek: 0,
            todayTaskCount: 0,
            averageDailyTaskCountPastWeek: 0,
            trend: .flat,
            comment: "",
            taskTypeCounts: [:]
        )
    }


    func energySummary(
        from history: [EnergyHistoryEntry],
        metrics: [DailyActivityMetrics]? = nil,
        tasks: [UserTask] = [],
        days: Int = 7
    ) -> EnergySummary? {
        guard !history.isEmpty,
              let last = history.max(by: { $0.date < $1.date }) else { return nil }

        let calendar = TimeZoneManager.shared.calendar
        let now = Date()
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: now)!)

        let sorted = history.sorted { $0.date < $1.date }
        let previousEntry = sorted.dropLast().last
        let delta = last.totalEnergy - (previousEntry?.totalEnergy ?? last.totalEnergy)

        var todayAdd = 0
        var todayDeduct = 0
        var totalToday = 0
        var countToday = 0
        var previousEnergy: Int?

        for entry in sorted where calendar.isDate(entry.date, inSameDayAs: now) {
            totalToday += entry.totalEnergy
            countToday += 1
            if let previous = previousEnergy {
                let difference = entry.totalEnergy - previous
                if difference > 0 {
                    todayAdd += difference
                } else {
                    todayDeduct -= difference
                }
            }
            previousEnergy = entry.totalEnergy
        }

        let todayDelta = todayAdd - todayDeduct
		let averageToday = countToday > 0 ? totalToday / countToday : 0

        // Calculate energy gained from tasks by day (PRD requirement: sum by day, then average)
        var taskEnergyPerDay: [Date: Int] = [:]
        for task in tasks where task.status == .completed, let completedAt = task.completedAt {
            let day = calendar.startOfDay(for: completedAt)
            if completedAt >= startDate {
                taskEnergyPerDay[day, default: 0] += task.energyReward
            }
        }
        
        // Also track energy changes from history for "use" calculation
        var usePerDay = [Date: Int]()
        var sumPerDay = [Date: (total: Int, count: Int)]()
        previousEnergy = nil

        for entry in sorted where entry.date >= startDate {
            let day = calendar.startOfDay(for: entry.date)
            if let previous = previousEnergy {
                let difference = entry.totalEnergy - previous
                if difference < 0 {
                    usePerDay[day, default: 0] += abs(difference)
                }
            }

            var bucket = sumPerDay[day] ?? (0, 0)
            bucket.total += entry.totalEnergy
            bucket.count += 1
            sumPerDay[day] = bucket
            previousEnergy = entry.totalEnergy
        }

        let dayCount = max(1, days) // Use window size for averaging
		// Average daily energy gained from tasks (sum by day, then average)
		let totalTaskEnergy = taskEnergyPerDay.values.reduce(0, +)
		let averageAddWeek = Int(Double(totalTaskEnergy) / Double(dayCount))
		let averageUseWeek = Int(Double(usePerDay.values.reduce(0, +)) / Double(dayCount))
		
		// Average daily total energy (not add)
		let totalSum = sumPerDay.values.reduce(0) { $0 + ($1.total / max($1.count, 1)) }
		let averageWeek = Int(Double(totalSum) / Double(dayCount))

        var todayTaskCount = 0
        var averageTaskCountWeek: Double = 0
        
        var score = todayAdd > averageAddWeek ? 1 : (todayAdd < averageAddWeek ? -1 : 0)
        if let metrics {
            let metricsByDay = Dictionary(uniqueKeysWithValues: metrics.map { (calendar.startOfDay(for: $0.date), $0) })
            
            // Task Counts
            if let todayMetric = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
                todayTaskCount = todayMetric.completedTaskCount
            }
            let weekMetrics = metrics.filter { $0.date >= startDate }
            let totalTasksWeek = weekMetrics.reduce(0) { $0 + $1.completedTaskCount }
            averageTaskCountWeek = Double(totalTasksWeek) / Double(max(1, days)) // Using 'days' (7) as divisor for weekly average, or dayCount? usually 7.
            
            let daysSorted = Array(sumPerDay.keys).sorted()
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
            if secondHalfTasks > firstHalfTasks { score += 1 }
            else if secondHalfTasks < firstHalfTasks { score -= 1 }
            if secondHalfInteractions > firstHalfInteractions { score += 1 }
            else if secondHalfInteractions < firstHalfInteractions { score -= 1 }
        }
        let trend: TrendDirection = score > 0 ? .up : (score < 0 ? .down : .flat)

		let comment: String = {
			var parts: [String] = []

			if let metrics {
				let totalTasks = metrics.reduce(0) { $0 + $1.completedTaskCount }
				let totalInteractions = metrics.reduce(0) { $0 + $1.petInteractionCount }
				parts.append("You've completed \(totalTasks) in \(days) days，and interacted with Lumio \(totalInteractions) times. Keep it up!")
			}

			switch trend {
			case .up:
				parts.append("You've done great job recently！")
			case .down:
				parts.append("You came less these days, the energy pod is drying. Try to complete more tasks and interact with Lumio more often!")
			case .flat:
				parts.append("Your routine is being established. Keep going!")
			}

			return parts.joined(separator: "\n")
		}()

        let taskTypeCounts = taskCategoryCompletionRatio(tasks: tasks)

        return EnergySummary(
            lastEnergy: last.totalEnergy,
            delta: delta,
            todayAdd: todayAdd,
            todayDeduct: todayDeduct,
            todayDelta: todayDelta,
            averageDailyAddPastWeek: averageAddWeek,
            averageDailyUsePastWeek: averageUseWeek,
            averageToday: averageToday,
            averagePastWeek: averageWeek,
            todayTaskCount: todayTaskCount,
            averageDailyTaskCountPastWeek: averageTaskCountWeek,
            trend: trend,
            comment: comment,
            taskTypeCounts: taskTypeCounts
        )
    }

    func taskCategoryCompletionRatio(tasks: [UserTask]) -> [TaskCategory: Int] {
        let completed = tasks.filter { $0.status == .completed }
        var counts: [TaskCategory: Int] = [:]
        for task in completed {
            counts[task.category, default: 0] += 1
        }
        return counts
    }
}
