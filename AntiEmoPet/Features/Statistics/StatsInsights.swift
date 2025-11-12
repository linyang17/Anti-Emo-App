import SwiftUI

struct StatsInsightsSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	let mood: MoodStatisticsViewModel.MoodSummary
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "小狐狸的观察", icon: "sparkles") {
			VStack(alignment: .leading, spacing: 10) {

				// 情感反馈（来自各自 Summary 的轻量文案）
				Group {
					Text(mood.comment.isEmpty ? "总结：暂无数据" : "总结：\(mood.comment)")
							.font(.subheadline)
				}

				Divider()

				// 情绪 / 能量的关联与交互分析（轻量可解释，无需改数据结构）
				/// TODO - 加入statistical analysis和图表
				
				VStack(alignment: .leading, spacing: 6) {
					Text("分析")
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
					Text("小提示：\(combined)")
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
			return "情绪与能量今天走得很同步，小狐狸看到你整体状态相对一致。"
		default:
			// 若方向不一致，用轻量说明提示用户关注身心落差
			return "情绪和能量的变化略有不一致，可以留意一下是不是“心累”或“身体累”其一在拖后腿。"
		}
	}

	/// 根据今日补充 / 消耗 / 净变化，给出能量使用模式的解释
	func energyUsagePatternText(energy: EnergyStatisticsViewModel.EnergySummary) -> String {
		if energy.todayAdd == 0 && energy.todayDeduct == 0 {
			return "今天还没有记录能量使用，小狐狸建议尝试标记一次补充或消耗，看看模式。"
		}

		if energy.todayDelta > 0 {
			return "今天是偏补充的一天，你有在为自己充值，这是很好的节奏。"
		} else if energy.todayDelta < 0 {
			return "今天能量略有透支，试试安排一点简单放松或早睡，帮自己补回来。"
		} else {
			return "今天能量收支大致平衡，保持这样的节奏也很不错。"
		}
	}

	/// 任务完成率与情绪改善的占位说明：后续可接入 Task 数据，直接在此输出统计结论
	func taskEffectPlaceholderText() -> String {
		let metrics = appModel.dailyMetricsCache
		guard !metrics.isEmpty else {
			return "当你完成更多外出 / 自我照顾任务时，小狐狸会在这里告诉你这些任务对情绪提升的实际效果。"
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
			return "已开始观察任务完成与情绪的关系，收集更多天的数据后会给出更可靠的结论。"
		}
		let withTasks = dayAverages.filter { $0.tasks > 0 }.map { $0.mood }
		let withoutTasks = dayAverages.filter { $0.tasks == 0 }.map { $0.mood }
		let avgWith = withTasks.isEmpty ? nil : (withTasks.reduce(0,+) / Double(withTasks.count))
		let avgWithout = withoutTasks.isEmpty ? nil : (withoutTasks.reduce(0,+) / Double(withoutTasks.count))
		if let a = avgWith, let b = avgWithout {
			if a > b + 2 {
				return "统计显示：完成任务的日子，情绪平均更高（≈\(String(format: "%.1f", a - b)) 分）。继续保持！"
			} else if b > a + 2 {
				return "观察发现：未完成任务的日子情绪更高一些，试试把任务拆小、降低压力。"
			} else {
				return "目前任务完成与情绪的差异不明显，建议继续记录一段时间以观察趋势。"
			}
		}
		return "正在积累数据以评估任务完成与情绪的关系。"
	}

	/// 外部因素（睡眠 / 活动 / 天气等）的占位说明：后续可对接数据源，不改本视图结构
	func externalFactorsPlaceholderText() -> String {
		return "未来支持连接睡眠、步数、天气等数据后，小狐狸会标记出哪些外部因素最影响你的情绪与能量。"
	}
}



struct StatsEmptyStateSection: View {
	var body: some View {
		DashboardCard(title: "暂无统计数据", icon: "calendar.badge.exclamationmark") {
			VStack(spacing: 8) {
				Text("还没有足够的记录。")
					.font(.headline)
				Text("多和小狐狸互动、记录情绪和能量，我会帮你看出规律和进步哦。")
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
		if moodLevel <= 3 && energyLevel <= 30 {
			return "今天是不是有点累呢？别着急，不如先放松一下，完成一个小任务，或者试试一些轻松的运动活动。"
		}

		// 情绪低但能量高 → 引导把能量用在商店里
		if moodLevel <= 4 && energyLevel >= 100 {
			return "你是不是有点不开心呢？要不去商店里给Lumio买个新装扮，或者和它聊一聊，也许能让你心情稍微好一点呢。"
		}

		// 情绪一般但能量低 → 建议温和补充
		if moodLevel >= 5 && energyLevel <= 30 {
			return "最近你的心情好像一般，试试早点休息，做一件平时让你放松的小事，多关注自己，给自己一些鼓励吧。"
		}

		// 情绪不错
		if moodLevel >= 7 {
			return "看来最近你有在好好生活呢！继续保持哦！"
		}

		// 其他情况不给多余噪音
		return nil
	}
}


