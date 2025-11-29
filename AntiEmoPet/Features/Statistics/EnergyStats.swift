import SwiftUI
import Charts

struct EnergyStatsSection: View {
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Energy Added Summary", icon: "bolt.fill") {
			VStack(alignment: .leading, spacing: 8) {
                // Top Section: Latest / Today
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Today Added:")
                        .font(.title2.weight(.semibold))
                    Text("\(energy.todayAdd)")
                        .font(.title2.weight(.semibold))
                }

				Divider().padding(.vertical, 6)

                // Stats Grid
				HStack(spacing: 20) {
					VStack(alignment: .leading, spacing: 12) {
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Added Past Week")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("\(energy.averageDailyAddPastWeek)")
								.font(.title3.weight(.medium))
						}
						
						VStack(alignment: .leading, spacing: 5) {
							Text("Tasks Done Today")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text("\(energy.todayTaskCount)")
								.font(.title3.weight(.medium))
						}
					}
					.frame(maxWidth: .w(0.45))
					
					Spacer()
					
					VStack(alignment: .leading, spacing: 12) {
						
						VStack(alignment: .leading, spacing: 5) {
							Text("Trend")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text(energy.trend.rawValue)
								.font(.title3.weight(.medium))
								.foregroundStyle(energy.trend == .up ? .green : (energy.trend == .down ? .red : .primary))
						}
						
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Tasks Done Past Week")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text(String(format: "%.0f", energy.averageDailyTaskCountPastWeek))
								.font(.title3.weight(.medium))
						}
					}
					.frame(maxWidth: .w(0.45))
				}
				.padding(.bottom, 12)
				
                // Comment
				Text(energy.comment.isEmpty ? "Come more often for summary" : energy.comment)
						.font(.subheadline)
						.foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                
                // Pie Chart
                if !energy.taskTypeCounts.isEmpty {
                    Divider().padding(.vertical, 8)
                    Text("Completed Tasks by Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
					
					let theme = ChartTheme.shared
					let sortedCategories = energy.taskTypeCounts.keys.sorted { $0.title < $1.title }
                    Chart(energy.taskTypeCounts.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                        SectorMark(
                            angle: .value("Count", item.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 1
                        )
						.foregroundStyle(by: .value("Category", item.key.title))
                        .cornerRadius(4)
                    }
					.chartForegroundStyleScale(
						domain: sortedCategories.map { $0.title },
						range: sortedCategories.map { theme.gradient(for: $0) }
					)
                    .frame(height: 200)
					.chartLegend(position: .bottom, alignment: .center, spacing: 24)
                }
			}
            .padding(.vertical, 6)
		}
	}
}

