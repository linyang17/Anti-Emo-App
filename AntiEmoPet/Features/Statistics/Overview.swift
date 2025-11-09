import SwiftUI


struct StatisticsOverviewSection: View {
	let mood: StatisticsViewModel.MoodSummary
	let energy: StatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "概览", icon: "heart.fill") {
			VStack(alignment: .leading, spacing: 12) {
				// 情绪快速概览
				HStack(alignment: .firstTextBaseline, spacing: 16) {
					VStack(alignment: .leading, spacing: 4) {
						Text("情绪")
							.font(.caption)
							.foregroundStyle(.secondary)
						Text("\(mood.lastMood)")
							.font(.title2.weight(.semibold))
						Text("今日平均 \(mood.averageToday) · 过去7天 \(mood.averagePastWeek)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					Spacer(minLength: 16)

					// 打卡情况：天数 & 总记录数
					VStack(alignment: .leading, spacing: 4) {
						Text("已记录天数")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("\(mood.uniqueDayCount) 天")
							.font(.subheadline.weight(.medium))

						Text("情绪记录总数")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("\(mood.entriesCount) 条")
							.font(.subheadline.weight(.medium))
					}
				}

				Divider()

				// 能量快速概览
				HStack(alignment: .firstTextBaseline, spacing: 16) {
					VStack(alignment: .leading, spacing: 4) {
						Text("能量")
							.font(.caption)
							.foregroundStyle(.secondary)
						Text("\(energy.lastEnergy)")
							.font(.title3.weight(.semibold))
						Text("今日补充 \(energy.todayAdd) · 过去7天 \(energy.averageAddPastWeek)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}

				}
			}
		}
	}
}
