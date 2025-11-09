import SwiftUI

struct StatsInsights: View {
	let mood: StatisticsViewModel.MoodSummary
	let energy: StatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "小狐狸的观察 / Insights", icon: "sparkles") {
			VStack(alignment: .leading, spacing: 8) {
				Text("情绪总结：\(mood.insight)")
					.font(.subheadline)

				Text("能量总结：\(energy.insight)")
					.font(.subheadline)

				// 可选：基于组合信号给出一条简短建议（逻辑在 ViewModel 里实现，避免这里写死）
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
