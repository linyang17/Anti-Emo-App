import SwiftUI
import Charts

struct EnergyStatsSection: View {
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Energy Added Summary", icon: "bolt.fill") {
			VStack(alignment: .leading, spacing: 8) {
				// Top Section: Latest / Today
				HStack(alignment: .firstTextBaseline, spacing: 6) {
					Text("Today Added: ")
						.appFont(FontTheme.title3)
					Text("\(energy.todayAdd)")
						.appFont(FontTheme.title3)
						.bold()
				}

				Divider().padding(.vertical, 6)

				HStack(spacing: 20) {
					VStack(alignment: .leading, spacing: 12) {
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Added Past Week")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text("\(energy.averageDailyAddPastWeek)")
								.appFont(FontTheme.headline)
								.bold()
						}
						
						VStack(alignment: .leading, spacing: 5) {
							Text("Tasks Done Today")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text("\(energy.todayTaskCount)")
								.appFont(FontTheme.headline)
								.bold()
						}
					}
					
					Spacer(minLength: 0)
					
					VStack(alignment: .leading, spacing: 12) {
						
						VStack(alignment: .leading, spacing: 5) {
							Text("Trend")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text(Image(systemName: energy.trend.rawValue))
								.font(.title3.weight(.medium))
								.foregroundStyle(energy.trend == .up ? .green : (energy.trend == .down ? .red : .primary))
						}
						
						VStack(alignment: .leading, spacing: 5) {
							Text("Avg Done Past Week")
								.appFont(FontTheme.subheadline)
								.foregroundStyle(.secondary)
							Text(String(format: "%.0f", energy.averageDailyTaskCountPastWeek))
								.appFont(FontTheme.headline)
								.bold()
						}
					}
				}
				.padding(.bottom, 12)
				
				// Comment
				Text(energy.comment.isEmpty ? "Come more often for a summary" : energy.comment)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				
				// Pie Chart
				if !energy.taskTypeCounts.isEmpty {
					Divider().padding(.vertical, 8)
					
					Text("Completed Tasks by Type")
						.appFont(FontTheme.subheadline)
						.foregroundStyle(.secondary)
						.padding(.bottom, 12)
					
					let theme = ChartTheme.shared
					let sortedCategories: [TaskCategory] = Array(energy.taskTypeCounts.keys).sorted { (lhs: TaskCategory, rhs: TaskCategory) in
						lhs.localizedTitle < rhs.localizedTitle
					}
					
					Chart(Array(energy.taskTypeCounts).sorted { (lhs: (key: TaskCategory, value: Int), rhs: (key: TaskCategory, value: Int)) in
						lhs.value > rhs.value
					}, id: \.key) { item in
						SectorMark(
							angle: .value("Count", item.value),
							innerRadius: .ratio(0.5),
							angularInset: 1
						)
						.foregroundStyle(by: .value("Category", item.key.localizedTitle))
						.cornerRadius(4)
					}
					.chartForegroundStyleScale(
						domain: sortedCategories.map { $0.localizedTitle },
						range: sortedCategories.map { theme.gradient(for: $0) }
					)
					.frame(width: .w(0.8), height: 200)
					.chartLegend(position: .bottom, alignment: .center, spacing: 32)
				}
			}
			.padding(.vertical, 6)
		}
	}
}
