import SwiftUI

struct StatsInsightsSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	let mood: MoodStatisticsViewModel.MoodSummary
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Lumio‘s Observation", icon: "sparkles") {
			VStack(alignment: .leading, spacing: 10) {

				// 情感反馈（来自各自 Summary 的轻量文案）
				Group {
					Text(mood.comment.isEmpty ? "Not enough data." : "Summary: \(mood.comment)")
							.font(.subheadline)
				}

				Divider()

				// 情绪 / 能量的关联与交互分析（轻量可解释，无需改数据结构）
				/// TODO - 加入statistical analysis和图表
				
				VStack(alignment: .leading, spacing: 6) {
					Text("Analysis")
						.font(.subheadline)
						.foregroundStyle(.secondary)

					// 情绪与能量相关感（基于水平与趋势的一致性）
					Text(moodEnergyCorrelationText(mood: mood, energy: energy))
						.font(.subheadline)

					// 能量使用模式：今天是「补充型」还是「透支型」
					Text(energyUsagePatternText(energy: energy))
						.font(.subheadline)

					// 任务完成率与情绪改善（占位说明：可直接接 Task 数据，不需改此 View）
					Text(taskEffectPlaceholderText())
						.font(.subheadline)
						.foregroundStyle(.secondary)

					// 睡眠 / 活动 等扩展信号（占位说明：未来可对接外部数据源）
					Text(externalFactorsPlaceholderText())
						.font(.subheadline)
						.foregroundStyle(.secondary)
				}

				// 组合建议：根据当前情绪 x 能量给出一条小提示
				if let combined = mood.combinedAdvice(with: energy) {
					Divider()
					Text("Tip: \(combined)")
						.font(.subheadline.weight(.medium))
				}
			}
			.foregroundStyle(.secondary)
		}
	}
}

private extension StatsInsightsSection {
	/// 基于情绪 & 能量水平 + 趋势给出「匹配度」描述，模拟情绪与能量相关系数的直觉反馈
	func moodEnergyCorrelationText(mood: MoodStatisticsViewModel.MoodSummary,
								   energy: EnergyStatisticsViewModel.EnergySummary) -> String {
		// 使用简单启发式：趋势一致 & 数值区间接近 → 高相关；否则给出中性提示
		switch (mood.trend, energy.trend) {
		case (.up, .up), (.down, .down), (.flat, .flat):
			return "Your mood and energy are moving in sync today — the fox notices your overall balance."
		default:
			// 若方向不一致，用轻量说明提示用户关注身心落差
			return "Your mood and energy seem slightly out of sync — maybe your mind or body is a bit tired."
		}
	}

	/// 根据今日补充 / 消耗 / 净变化，给出能量使用模式的解释
	func energyUsagePatternText(energy: EnergyStatisticsViewModel.EnergySummary) -> String {
		if energy.todayAdd == 0 && energy.todayDeduct == 0 {
			return "No energy activity recorded today. Try logging a recharge or spend to see your pattern."
		}

		if energy.todayDelta > 0 {
			return "Today seems more recharging — you’re giving yourself some energy back, which is great."
		} else if energy.todayDelta < 0 {
			return "You’re slightly running on empty today. Try some rest or an early night to recover."
		} else {
			return "Your energy is roughly balanced today — that’s a healthy rhythm to keep."
		}
	}

	/// 任务完成率与情绪改善的占位说明：后续可接入 Task 数据，直接在此输出统计结论
	func taskEffectPlaceholderText() -> String {
		let metrics = appModel.dailyMetricsCache
		guard !metrics.isEmpty else {
			return "Once you complete more outdoor or self-care tasks, the fox will show how they affect your mood."
		}
		// Build day -> completed count map
		let cal = TimeZoneManager.shared.calendar
		let countsByDay = Dictionary(uniqueKeysWithValues: metrics.map { (cal.startOfDay(for: $0.date), $0.completedTaskCount) })
		// Build mood per-day average
		var moodByDay: [Date: (sum: Int, count: Int)] = [:]
		for e in appModel.moodEntries {
			let d = cal.startOfDay(for: e.date)
			var v = moodByDay[d] ?? (0,0)
			v.sum += e.value
			v.count += 1
			moodByDay[d] = v
		}
		let dayAverages: [(tasks: Int, mood: Double)] = moodByDay.map { (key, val) in
			let avg = Double(val.sum) / Double(max(1, val.count))
			let t = countsByDay[key] ?? 0
			return (t, avg)
		}
		guard dayAverages.count >= 3 else {
			return "Tracking task completion and mood — more data will bring clearer insights soon."
		}
		let withTasks = dayAverages.filter { $0.tasks > 0 }.map { $0.mood }
		let withoutTasks = dayAverages.filter { $0.tasks == 0 }.map { $0.mood }
		let avgWith = withTasks.isEmpty ? nil : (withTasks.reduce(0,+) / Double(withTasks.count))
		let avgWithout = withoutTasks.isEmpty ? nil : (withoutTasks.reduce(0,+) / Double(withoutTasks.count))
		if let a = avgWith, let b = avgWithout {
			if a > b + 2 {
				return "Stats show that on task days, your mood is higher by about \(String(format: "%.1f", a - b)) points. Keep it up!"
			} else if b > a + 2 {
				return "Interestingly, mood seems higher on days without tasks — maybe try smaller, lighter goals."
			} else {
				return "No strong mood difference between task and non-task days yet. Keep tracking for trends."
			}
		}
		return "Collecting more data to analyze how tasks relate to mood."
	}

	/// 外部因素（睡眠 / 活动 / 天气等）的占位说明：后续可对接数据源，不改本视图结构
	func externalFactorsPlaceholderText() -> String {
		return "Once connected with sleep, steps, and weather data, the fox will show which factors affect your mood and energy most."
	}
}



struct StatsEmptyStateSection: View {
	var body: some View {
		DashboardCard(title: "No Statistics Yet", icon: "calendar.badge.exclamationmark") {
			VStack(spacing: 8) {
				Text("Not enough records yet.")
					.font(.headline)
				Text("Interact more with the fox and log your mood and energy — I’ll help reveal your progress and patterns.")
					.font(.caption)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.frame(maxWidth: .infinity, minHeight: 160)
		}
	}
}



private extension MoodStatisticsViewModel.MoodSummary {

	/// 轻量规则版：后面可无缝替换为 AI 模型，不影响调用方
	func combinedAdvice(with energy: EnergyStatisticsViewModel.EnergySummary) -> String? {
		// 轻量规则版：后面可无缝替换为 AI 模型，不影响调用方
		let moodLevel = averageToday
		let energyLevel = energy.averageToday

		// 情绪和能量都低 → 给温和、可执行的小目标
		if moodLevel <= 30 && energyLevel <= 30 {
			return "Feeling a bit tired today? Take it easy — do a small task or a light activity to unwind."
		}

		// 情绪低但能量高 → 引导把能量用在商店里
		if moodLevel <= 40 && energyLevel >= 100 {
			return "Feeling a little down? Maybe get Lumio a new outfit or have a chat — it might lift your mood."
		}

		// 情绪一般但能量低 → 建议温和补充
		if moodLevel >= 50 && energyLevel <= 30 {
			return "Your mood feels okay but your energy’s low — try resting early or doing something relaxing for yourself."
		}

		// 情绪不错
		if moodLevel >= 70 {
			return "Looks like you’ve been doing great lately! Keep it up!"
		}

		// 其他情况不给多余噪音
		return nil
	}
}
