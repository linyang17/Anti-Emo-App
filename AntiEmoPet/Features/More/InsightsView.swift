import SwiftUI

struct InsightsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var analysis = AnalysisViewModel()
	@StateObject private var moodViewModel = MoodStatisticsViewModel()
	@StateObject private var energyViewModel = EnergyStatisticsViewModel()

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
