import SwiftUI

struct EnergyStatsSection: View {
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Energy Added Summary", icon: "bolt.fill") {
			VStack(alignment: .leading, spacing: 8) {
				Text("Today：\(String(format: "%.0f", energy.todayAdd)) \(energy.trend.rawValue)")
					.font(.title2.weight(.semibold))
				
				Divider().padding(.vertical, 6)

				VStack(alignment: .leading, spacing: 5) {
					Text("Avg Past Week")
						.font(.subheadline)
						.foregroundStyle(.secondary)
					Text("\(energy.averageDailyAddPastWeek)")
						.font(.title2.weight(.medium))
				}
				.padding(.bottom, 12)
				
				Text(energy.comment.isEmpty ? "Come more often for summary" : energy.comment)
						.font(.subheadline)
						.foregroundStyle(.secondary)
			}
		}
	}
}
