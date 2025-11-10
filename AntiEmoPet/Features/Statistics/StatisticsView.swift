import SwiftUI
import Charts

struct StatisticsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var moodviewModel = MoodStatisticsViewModel()
	@StateObject private var energyviewModel = EnergyStatisticsViewModel()

	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				if let mood = moodviewModel.moodSummary(entries: appModel.moodEntries),
				   let energy = energyviewModel.energySummary(from: appModel.energyHistory, metrics: appModel.dailyMetricsCache) {

					// 1️⃣ 总览卡片：今日 vs 趋势
					StatisticsOverviewSection(mood: mood, energy: energy)

					// 2️⃣ 情绪统计区
					MoodStatsSection(mood: mood)

					// 3️⃣ 能量统计区
					EnergyStatsSection(energy: energy)

					// 4️⃣ 能量趋势（后续可扩展情绪趋势）
					if !appModel.energyHistory.isEmpty {
						EnergyTrendSection(energyHistory: appModel.energyHistory)
						MoodTrendSection().environmentObject(appModel)
					}

					StatisticsRhythmSection().environmentObject(appModel)

					// 5️⃣ 洞察与建议区
					StatsInsights(mood: mood, energy: energy)

				}
				else {
					StatisticsEmptyStateSection()
				}
			}
			.padding()
		}
		.navigationTitle("统计")
		.energyToolbar(appModel: appModel)
	}
}
