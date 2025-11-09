import SwiftUI


struct MoodStatsSection: View {
	let mood: StatisticsViewModel.MoodSummary

	var body: some View {
		DashboardCard(title: "情绪摘要", icon: "smile.fill") {
			VStack(alignment: .leading, spacing: 8) {
				// 最新情绪 + 趋势
				Text("最新情绪：\(mood.lastMood) \(mood.trendText)")
					.font(.title3.weight(.semibold))

				HStack {
					Text("今日平均：\(mood.averageToday)")
					Spacer()
					Text("过去7天平均：\(mood.averagePastWeek)")
				}
				.font(.subheadline)
				.foregroundStyle(.secondary)

				HStack {
					Text("累计打卡天数：\(mood.uniqueDayCount)")
					Spacer()
					Text("累计记录次数：\(mood.entriesCount)")
				}
				.font(.caption)
				.foregroundStyle(.secondary)

				Text(mood.insight)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		}
	}
}
