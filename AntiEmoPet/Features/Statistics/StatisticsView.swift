import SwiftUI
import Charts

struct StatisticsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var moodviewModel = MoodStatisticsViewModel()
	@StateObject private var energyviewModel = EnergyStatisticsViewModel()

	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				let mood = moodviewModel.moodSummary(entries: appModel.moodEntries) ?? MoodStatisticsViewModel.MoodSummary(
					lastMood: 0,
					delta: 0,
					averageToday: 0,
					averagePastWeek: 0,
					uniqueDayCount: 0,
					entriesCount: 0,
					trend: .flat,
					comment: ""
				)
				let energy = energyviewModel.energySummary(from: appModel.energyHistory, metrics: appModel.dailyMetricsCache) ?? EnergyStatisticsViewModel.EnergySummary(
					lastEnergy: 0,
					delta: 0,
					todayAdd: 0,
					todayDeduct: 0,
					todayDelta: 0,
					averageDailyAddPastWeek: 0,
					averageDailyUsePastWeek: 0,
					averageToday: 0,
					averagePastWeek: 0,
					trend: .flat,
					comment: ""
				)

				// 1️⃣ 总览卡片：今日 vs 趋势
				StatisticsOverviewSection(mood: mood, energy: energy)

				// 2️⃣ 情绪统计区
				MoodStatsSection(mood: mood)

				// 3️⃣ 能量统计区
				EnergyStatsSection(energy: energy)

				// 4️⃣ 趋势区：能量与情绪
				EnergyTrendSection(energyHistory: appModel.energyHistory)
				MoodTrendSection().environmentObject(appModel)

				// 5️⃣ 节律分析：时段 / 天气 / 日照提示
				StatisticsRhythmSection().environmentObject(appModel)

				// 6️⃣ 洞察与建议区
				StatsInsights(mood: mood, energy: energy).environmentObject(appModel)
			}
			.padding()
		}
		.navigationTitle("统计")
		.energyToolbar(appModel: appModel)
	}
}
