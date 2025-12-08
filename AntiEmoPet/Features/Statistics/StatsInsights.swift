import SwiftUI

struct StatsInsightsSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	let mood: MoodStatisticsViewModel.MoodSummary
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Lumio‘s Observation", icon: "sparkles") {
				// 情感反馈（来自各自 Summary 的轻量文案）
				VStack(alignment: .leading, spacing: 8) {
					Text("Summary:")
						.appFont(FontTheme.subheadline)
					Text(mood.comment.isEmpty ? "Not enough data." : "\(mood.comment)")
				}

				Divider()

				// TODO: 情绪 / 能量的关联与交互分析（轻量，无需改数据结构）
				
				VStack(alignment: .leading, spacing: 8) {
					Text("Analysis:")
						.appFont(FontTheme.subheadline)
						.foregroundStyle(.secondary)

					// 任务完成率与情绪改善效果
					Text(taskEffectPlaceholderText())
						.foregroundStyle(.secondary)

					// TODO: 睡眠 / 活动 等扩展信号（未来可对接health数据源）
					
				}

				// 组合建议：根据当前情绪 x 能量 x timeslot x 天气给出一条小提示
				if let combined = mood.combinedAdvice(with: energy) {
					Divider()
					Text("Tips:")
						.appFont(FontTheme.subheadline)
					Text("\(combined)")
						.foregroundStyle(.secondary)
				}
			}
			.foregroundStyle(.secondary)
		}
	}

private extension StatsInsightsSection {
	// TODO: 基于情绪 & 能量水平 + 趋势给出「匹配度」描述，模拟情绪与能量相关系数的直觉反馈
	func moodEnergyCorrelationText(mood: MoodStatisticsViewModel.MoodSummary,
								   energy: EnergyStatisticsViewModel.EnergySummary) -> String {
		switch (mood.trend, energy.trend) {
		case (.up, .up), (.down, .down), (.flat, .flat):
			return "Your effort is well paid off — Lumio notices your overall balance."
		default:
			return "Your mood and energy seem slightly out of sync — maybe take some adjuestment on how you try to manage them."
		}
	}


	// TODO: 基于任务完成率与情绪改善效果，模拟情绪与能量增长的相关反馈
	func taskEffectPlaceholderText() -> String {
		let metrics = appModel.dailyMetricsCache
		guard metrics.count >= 5 else {
			return "Once you complete more tasks and mood records, Lumio will be able to help you track the effectiveness and help you improve your progress better."
		}
		// Build day -> completed count map
		let cal = TimeZoneManager.shared.calendar
		let countsByDay = Dictionary(uniqueKeysWithValues: metrics.map { (cal.startOfDay(for: $0.date), $0.completedTaskCount) })
		// Build average mood delta per day
		var moodDeltaByDay: [Date: (sum: Int, count: Int)] = [:]
		for e in appModel.moodEntries {
			let d = cal.startOfDay(for: e.date)
			var v = moodDeltaByDay[d] ?? (0,0)
			v.sum += e.delta ?? 0
			v.count += 1
			moodDeltaByDay[d] = v
		}
		let dayAverages: [(tasks: Int, mood: Double)] = moodDeltaByDay.map { (key, val) in
			let avg = Double(val.sum) / Double(max(1, val.count))
			let t = countsByDay[key] ?? 0
			return (t, avg)
		}
		guard dayAverages.count >= 3 else {
			return "Try to complete more tasks to bring clearer insights on how your mood improves with them."
		}
		let withTasks = dayAverages.filter { $0.tasks > 0 }.map { $0.mood }
		let withoutTasks = dayAverages.filter { $0.tasks == 0 }.map { $0.mood }
		let avgWith = withTasks.isEmpty ? nil : (withTasks.reduce(0,+) / Double(withTasks.count))
		let avgWithout = withoutTasks.isEmpty ? nil : (withoutTasks.reduce(0,+) / Double(withoutTasks.count))
		if let a = avgWith, let b = avgWithout {
			if a > b + 2 {
				return "When you complete more tasks, your mood is higher by about \(String(format: "%.0f", a - b)) points. You're doing a great job, keep it up!"
			} else if b > a + 2 {
				return "Looks like you've managed to find a balance yourself - Lumio feels so proud of you!"
			} else {
				return "Tasks seems to make little difference on mood improvement - might be worth finding some more activities that can actually help."
			}
		}
		return ""
	}

}



struct StatsEmptyStateSection: View {
	var body: some View {
		DashboardCard(title: "No Statistics Yet", icon: "calendar.badge.exclamationmark") {
			VStack(spacing: 8) {
				Text("Not enough records yet.")
					.appFont(FontTheme.headline)
				Text("Interact more with the fox and log your mood and energy — I’ll help reveal your progress and patterns.")
					.appFont(FontTheme.caption)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.frame(maxWidth: .infinity, minHeight: 160)
		}
	}
}



private extension MoodStatisticsViewModel.MoodSummary {

	func combinedAdvice(with energy: EnergyStatisticsViewModel.EnergySummary) -> String? {
		let energyAddToday = energy.todayAdd
		
		// 情绪低并且完成任务没有效果 → 安慰没关系
		if averageToday <= 40 && delta <= 0 && energyAddToday >= 30 {
			return "Feeling a little down even if you've made some effort to get active? Don't worry, it's okay to allow yourself some down time, and you don't always have to ace everything in life."
		}
		
		// 情绪低但是完成任务有效果 → 鼓励
		if averageToday <= 40 && delta > 0 && energyAddToday >= 30 {
			return "The day starts low, but you've made the effort to boost yourself up and it’s clearly working! Keep going and you’ll see more positive changes in no time. "
		}

		if averageToday >= 40 && averageToday <= 70 && energyAddToday <= 30 {
			return "It seems to be a normal day — try to take some exercises today or doing something relaxing for yourself."
		}
		
		if trend == .down && energyAddToday > 30 {
			return "Feeling a bit tired recently? Take it easy — take some light activities to unwind or allow yourself some rest, you’ll be back on track soon."
		}

		if averageToday > 70, trend == .up {
			return "Looks like you’ve been doing great lately! Keep the momentum up and you’ll continue to see positive changes over time."
		}

		// 其他情况不给tips
		return "Let's keep the momentum going and see where this journey takes us!"
	}
}
