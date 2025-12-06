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
					// 情绪统计区
					MoodStatsSection(mood: moodSummary)
					MoodTrendSection().environmentObject(appModel)

					// 能量统计区
					EnergyStatsSection(energy: energySummary)
					EnergyTrendSection(energyHistory: appModel.energyHistory, energy: energySummary)
					}
                }
		.navigationTitle("Statistics")
		.task {
			refreshSummaries()
		}
		.onChange(of: appModel.moodEntries.count) { _, _ in refreshSummaries() }
		.onChange(of: appModel.energyHistory.count) { _, _ in refreshSummaries() }
		.onChange(of: appModel.dailyMetricsCache.count) { _, _ in refreshSummaries() }
	}

	private func refreshSummaries() {
		// Avoid redundant calculation during loading
		guard !appModel.isLoading else { return }
		
                moodSummary = moodViewModel.moodSummary(entries: appModel.moodEntries) ?? .empty
                energySummary = energyViewModel.energySummary(
                        metrics: appModel.dailyMetricsCache,
                        tasks: appModel.tasksSince(days: 30, includeArchived: true, includeOnboarding: false)
                ) ?? .empty
        }
}
