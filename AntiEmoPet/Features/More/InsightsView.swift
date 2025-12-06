import SwiftUI

struct InsightsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var analysis = AnalysisViewModel()
	@StateObject private var moodViewModel = MoodStatisticsViewModel()

	@State private var moodSummary: MoodStatisticsViewModel.MoodSummary = .empty
	@State private var energySummary: EnergyStatisticsViewModel.EnergySummary = .empty

	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				
				StatsRhythmSection().environmentObject(appModel)

				StatsInsightsSection(mood: moodSummary, energy: energySummary)
					.environmentObject(appModel)
				
			}
			.padding()
		}
		.navigationTitle("Insights")
		.task {
			refreshSummaries()
		}
		.onChange(of: appModel.moodEntries.count) { _, _ in refreshSummaries() }
		.onChange(of: appModel.energyHistory.count) { _, _ in refreshSummaries() }
		.onChange(of: appModel.dailyMetricsCache.count) { _, _ in refreshSummaries() }
		.onChange(of: appModel.todayTasks) { _, _ in refreshSummaries() }
	}

    private func refreshSummaries() {
		// Avoid redundant calculation during loading
		guard !appModel.isLoading else { return }

        moodSummary = moodViewModel.moodSummary(entries: appModel.moodEntries) ?? .empty
    }
}
