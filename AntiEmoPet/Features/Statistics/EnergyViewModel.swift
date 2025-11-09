import Foundation
import Combine

@MainActor
final class EnergyStatisticsViewModel: ObservableObject {

	struct EnergySummary {
		let lastEnergy: Int
		let delta: Int
		let todayAdd: Int
		let todayDeduct: Int
		let todayDelta: Int
		let averageDailyAddPastWeek: Double
		let averageDailyUsePastWeek: Double
		let averageToday: Double
		let averagePastWeek: Double
		let trend: TrendDirection
		let comment: String
	}

	private func rounded(_ value: Double) -> Double {
		(value * 10).rounded() / 10
	}

	// MARK: - Energy Summary
	func energySummary(from history: [EnergyHistoryEntry], metrics: [DailyActivityMetrics]? = nil, days: Int = 7) -> EnergySummary? {
		guard !history.isEmpty,
			  let last = history.max(by: { $0.date < $1.date }) else { return nil }

		let cal = TimeZoneManager.shared.calendar
		let now = Date()
		let startDate = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(1, days) - 1), to: now)!)

		// Sort once
		let sorted = history.sorted { $0.date < $1.date }
		let prev = sorted.dropLast().last
		let delta = last.totalEnergy - (prev?.totalEnergy ?? last.totalEnergy)

		// --- Today ---
		var todayAdd = 0, todayDeduct = 0
		var totalToday = 0, countToday = 0
		var prevEnergy: Int?

		for entry in sorted where cal.isDate(entry.date, inSameDayAs: now) {
			totalToday += entry.totalEnergy
			countToday += 1
			if let p = prevEnergy {
				let diff = entry.totalEnergy - p
				if diff > 0 { todayAdd += diff } else { todayDeduct -= diff }
			}
			prevEnergy = entry.totalEnergy
		}

		let todayDelta = todayAdd - todayDeduct
		let avgToday = countToday > 0 ? rounded(Double(totalToday) / Double(countToday)) : 0.0

		// --- Past N Days ---
		var addPerDay = [Date: Int]()
		var usePerDay = [Date: Int]()
		var sumPerDay = [Date: (total: Int, count: Int)]()
		prevEnergy = nil

		for entry in sorted where entry.date >= startDate {
			let day = cal.startOfDay(for: entry.date)
			// No reset of prevEnergy on day change
			if let p = prevEnergy {
				let diff = entry.totalEnergy - p
				if diff > 0 {
					addPerDay[day, default: 0] += diff
				} else {
					usePerDay[day, default: 0] += abs(diff)
				}
			}

			sumPerDay[day, default: (0, 0)].total += entry.totalEnergy
			sumPerDay[day, default: (0, 0)].count += 1
			prevEnergy = entry.totalEnergy
		}

		let dayCount = sumPerDay.count
		let avgAddWeek = dayCount > 0 ? rounded(Double(addPerDay.values.reduce(0, +)) / Double(dayCount)) : 0.0
		let avgUseWeek = dayCount > 0 ? rounded(Double(usePerDay.values.reduce(0, +)) / Double(dayCount)) : 0.0
		let avgWeek = dayCount > 0
			? rounded(sumPerDay.values.reduce(0.0) {
				$0 + Double($1.total) / Double($1.count)
			} / Double(dayCount))
			: 0.0

		var score = avgToday > avgWeek ? 1 : (avgToday < avgWeek ? -1 : 0)
		if let metrics {
			let metricsByDay = Dictionary(uniqueKeysWithValues: metrics.map { (TimeZoneManager.shared.calendar.startOfDay(for: $0.date), $0) })
			let daysSorted = Array(sumPerDay.keys).sorted()
			let mid = daysSorted.count / 2
			var firstHalfTasks = 0, secondHalfTasks = 0
			var firstHalfInter = 0, secondHalfInter = 0
			for (i, d) in daysSorted.enumerated() {
				if let m = metricsByDay[d] {
					if i < mid { firstHalfTasks += m.completedTaskCount; firstHalfInter += m.petInteractionCount }
					else { secondHalfTasks += m.completedTaskCount; secondHalfInter += m.petInteractionCount }
				}
			}
			if secondHalfTasks > firstHalfTasks { score += 1 } else if secondHalfTasks < firstHalfTasks { score -= 1 }
			if secondHalfInter > firstHalfInter { score += 1 } else if secondHalfInter < firstHalfInter { score -= 1 }
		}
		let trend: TrendDirection = score > 0 ? .up : (score < 0 ? .down : .flat)

		let comment: String = {
			var parts: [String] = []
			switch trend {
			case .up: parts.append("最近能量在上升，做得很棒！")
			case .down: parts.append("最近能量略有下降，注意休息恢复哦。")
			case .flat: parts.append("能量水平保持稳定。")
			}
			parts.append("今日 +\(todayAdd) / -\(todayDeduct)")
			if let metrics {
				let totalTasks = metrics.reduce(0) { $0 + $1.completedTaskCount }
				let totalInter = metrics.reduce(0) { $0 + $1.petInteractionCount }
				parts.append("近\(days)天完成任务 \(totalTasks) 次，互动 \(totalInter) 次")
			}
			return parts.joined(separator: " · ")
		}()

		return EnergySummary(
			lastEnergy: last.totalEnergy,
			delta: delta,
			todayAdd: todayAdd,
			todayDeduct: todayDeduct,
			todayDelta: todayDelta,
			averageDailyAddPastWeek: avgAddWeek,
			averageDailyUsePastWeek: avgUseWeek,
			averageToday: avgToday,
			averagePastWeek: avgWeek,
			trend: trend,
			comment: comment
		)
	}
}
