import SwiftUI

struct EnergyStatsSection: View {
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "能量摘要 / Energy Stats", icon: "bolt.fill") {
			VStack(alignment: .leading, spacing: 8) {
				Text("今日平均能量：\(String(format: "%.1f", energy.averageToday)) \(trendArrow(for: energy))")
					.font(.title3.weight(.semibold))

				Text("过去7天平均：\(String(format: "%.1f", energy.averagePastWeek))")
					.font(.subheadline)
					.foregroundStyle(.secondary)

				HStack {
					VStack(alignment: .leading, spacing: 2) {
						Text("今日补充")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("+\(energy.todayAdd)")
							.font(.subheadline.weight(.medium))
					}

					Spacer()

					VStack(alignment: .leading, spacing: 2) {
						Text("今日消耗")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("-\(energy.todayDeduct)")
							.font(.subheadline.weight(.medium))
					}
				}

				Text(energy.comment)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		}
	}

	private func trendArrow(for energy: EnergyStatisticsViewModel.EnergySummary) -> String {
		switch energy.trend {
		case .up: return "↑"
		case .down: return "↓"
		default: return "→"
		}
	}
}
