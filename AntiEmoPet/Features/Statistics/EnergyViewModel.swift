//
//  EnergyStatisticsViewModel.swift
//  AntiEmoPet
//
//  Created by Selena Yang on 09/11/2025.
//


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

	enum TrendDirection: String {
		case up = "uparrow.2.fill"
		case down = "downarrow.2.fill"
		case flat = ""
	}

	private func rounded(_ value: Double) -> Double {
		(value * 10).rounded() / 10
	}

	// MARK: - Energy Summary
	func energySummary(from history: [EnergyHistoryEntry]) -> EnergySummary? {
		guard !history.isEmpty,
			  let last = history.max(by: { $0.date < $1.date }) else { return nil }

		let cal = Calendar.current
		let now = Date()
		let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!

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

		// --- Past 7 Days ---
		var addPerDay = [Date: Int]()
		var usePerDay = [Date: Int]()
		var sumPerDay = [Date: (total: Int, count: Int)]()
		prevEnergy = nil
		var lastDay: Date?

		for entry in sorted where entry.date >= weekAgo {
			let day = cal.startOfDay(for: entry.date)
			if day != lastDay { prevEnergy = nil }

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
			lastDay = day
		}

		let dayCount = sumPerDay.count
		let avgAddWeek = dayCount > 0 ? rounded(Double(addPerDay.values.reduce(0, +)) / Double(dayCount)) : 0.0
		let avgUseWeek = dayCount > 0 ? rounded(Double(usePerDay.values.reduce(0, +)) / Double(dayCount)) : 0.0
		let avgWeek = dayCount > 0
			? rounded(sumPerDay.values.reduce(0.0) {
				$0 + Double($1.total) / Double($1.count)
			} / Double(dayCount))
			: 0.0

		// --- Trend & comment ---
		let trend: TrendDirection = avgToday > avgWeek ? .up : (avgToday < avgWeek ? .down : .flat)
		let comment: String = switch trend {
		case .up: "最近有在好好生活！继续保持～"
		case .down: "最近很少关注自己，注意休息恢复哦。"
		case .flat: "能量水平保持稳定。"
		}

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