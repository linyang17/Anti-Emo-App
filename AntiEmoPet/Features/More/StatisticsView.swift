import SwiftUI
import Charts
import Combine

struct StatisticsView: View {
        @EnvironmentObject private var appModel: AppViewModel
        @StateObject private var moodViewModel = MoodStatisticsViewModel()
        @StateObject private var energyViewModel = EnergyStatisticsViewModel()

        @State private var moodSummary: MoodStatisticsViewModel.MoodSummary = .empty
        @State private var energySummary: EnergyStatisticsViewModel.EnergySummary = .empty

        var body: some View {
			ScrollView {
				VStack(spacing: 20) {
					// 1️⃣ 总览卡片：今日 vs 趋势
					//StatisticsOverviewSection(mood: moodSummary, energy: energySummary)

					// 2️⃣ 情绪统计区
					MoodStatsSection(mood: moodSummary)

					// 3️⃣ 能量统计区
					EnergyStatsSection(energy: energySummary)

					// 4️⃣ 趋势区：能量与情绪
					EnergyTrendSection(energyHistory: appModel.energyHistory, energy: energySummary)
					MoodTrendSection().environmentObject(appModel)
					}
                }
                .navigationTitle("统计")
                .onAppear(perform: refreshSummaries)
                .onReceive(appModel.$moodEntries) { _ in refreshSummaries() }
                .onReceive(appModel.$energyHistory) { _ in refreshSummaries() }
                .onReceive(appModel.$dailyMetricsCache) { _ in refreshSummaries() }
        }

        private func refreshSummaries() {
                moodSummary = moodViewModel.moodSummary(entries: appModel.moodEntries) ?? .empty
                energySummary = energyViewModel.energySummary(
                        from: appModel.energyHistory,
                        metrics: appModel.dailyMetricsCache
                ) ?? .empty
        }
}
