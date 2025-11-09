import Foundation
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {

	private static let percentFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .percent
		formatter.maximumFractionDigits = 0
		formatter.minimumFractionDigits = 0
		return formatter
	}()

	private static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "MM-dd HH:mm"
		return formatter
	}()

	// MARK: - Summary Structs
	struct MoodSummary {
		let lastMood: Int
		let delta: Int
		let averageToday: Int
		let averagePastWeek: Int
		let uniqueDayCount: Int
		let entriesCount: Int
		let trend: TrendDirection
		let insight: String
	}

	struct EnergySummary {
		let lastEnergy: Int
		let delta: Int
		let averageToday: Int
		let averagePastWeek: Int
		let trend: TrendDirection
		let insight: String
	}

	enum TrendDirection: String {
		case up = "⬆️"
		case down = "⬇️"
		case flat = "➡️"
	}

	// MARK: - Mood Summary
	func moodSummary(entries: [MoodEntry]) -> MoodSummary? {
		guard !entries.isEmpty else { return nil }

		let sorted = entries.sorted { $0.date < $1.date }
		guard let last = sorted.last else { return nil }
		let previous = sorted.dropLast().last
		let delta = last.value - (previous?.value ?? last.value)

		let cal = Calendar.current
		let now = Date()
		
		let days = Set(entries.map {cal.startOfDay(for: $0.date) })
		let dayCount = days.count
		let entryCount = entries.count

		let todayEntries = entries.filter { cal.isDate($0.date, inSameDayAs: now) }
		let avgToday = todayEntries.isEmpty ? 0 :
			Int(round(Double(todayEntries.map(\.value).reduce(0, +)) / Double(todayEntries.count)))

		let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
		let weekEntries = entries.filter { $0.date >= weekAgo }
		let avgWeek = weekEntries.isEmpty ? 0 :
			Int(round(Double(weekEntries.map(\.value).reduce(0, +)) / Double(weekEntries.count)))

		// Trend detection
		let trend: TrendDirection
		if avgToday > avgWeek { trend = .up }
		else if avgToday < avgWeek { trend = .down }
		else { trend = .flat }

		// Insight generation
		let insight: String
		switch trend {
		case .up:
			insight = "太好了，你的心情正在变好！"
		case .down:
			insight = "最近情绪略有下降，试着放松一下吧！"
		case .flat:
			insight = "最近情绪稳定，继续保持～"
		}

		return MoodSummary(
			lastMood: last.value,
			delta: delta,
			averageToday: avgToday,
			averagePastWeek: avgWeek,
			uniqueDayCount: dayCount,
			entriesCount: entryCount,
			trend: trend,
			insight: insight
		)
	}

	// MARK: - Energy Summary
	func energySummary(from history: [EnergyHistoryEntry]) -> EnergySummary? {
		guard !history.isEmpty else { return nil }

		let sorted = history.sorted { $0.date < $1.date }
		guard let last = sorted.last else { return nil }
		let previous = sorted.dropLast().last
		let delta = last.totalEnergy - (previous?.totalEnergy ?? last.totalEnergy)

		let cal = Calendar.current
		let now = Date()

		let todayEntries = history.filter { cal.isDate($0.date, inSameDayAs: now) }
		let avgToday = todayEntries.isEmpty ? 0 :
			Int(round(Double(todayEntries.map(\.totalEnergy).reduce(0, +)) / Double(todayEntries.count)))

		let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
		let weekEntries = history.filter { $0.date >= weekAgo }
		let avgWeek = weekEntries.isEmpty ? 0 :
			Int(round(Double(weekEntries.map(\.totalEnergy).reduce(0, +)) / Double(weekEntries.count)))

		// Trend detection
		let trend: TrendDirection
		if avgToday > avgWeek { trend = .up }
		else if avgToday < avgWeek { trend = .down }
		else { trend = .flat }

		// Insight generation
		let insight: String
		switch trend {
		case .up:
			insight = "你的能量状态提升了，效率上升中！"
		case .down:
			insight = "最近能量下降，注意休息恢复哦。"
		case .flat:
			insight = "能量水平保持稳定，继续保持～"
		}

		return EnergySummary(
			lastEnergy: last.totalEnergy,
			delta: delta,
			averageToday: avgToday,
			averagePastWeek: avgWeek,
			trend: trend,
			insight: insight
		)
	}
}
