import SwiftUI
import Charts

struct EnergyStatsSection: View {
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Energy Added Summary", icon: "bolt.fill") {
			VStack(alignment: .leading, spacing: 16) {
                // Today Summary
				VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .lastTextBaseline) {
                        Text("\(energy.todayAdd)")
                            .font(.title.weight(.bold))
                        Text("energy")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(energy.todayTaskCount)")
                            .font(.title.weight(.bold))
                        Text("tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if energy.trend != .flat {
                        Text(energy.trend.rawValue)
                            .font(.caption)
                            .foregroundStyle(energy.trend == .up ? .green : .red)
                    }
				}
				
				Divider()

                // Weekly Average
				VStack(alignment: .leading, spacing: 4) {
					Text("Avg Past Week")
						.font(.subheadline)
						.foregroundStyle(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(energy.averageDailyAddPastWeek)")
                                .font(.headline)
                            Text("Energy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text(String(format: "%.1f", energy.averageDailyTaskCountPastWeek))
                                .font(.headline)
                            Text("Tasks")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
				}
				
                // Comment
				Text(energy.comment.isEmpty ? "Come more often for summary" : energy.comment)
						.font(.subheadline)
						.foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                
                // Pie Chart
                if !energy.taskTypeCounts.isEmpty {
                    Divider()
                    Text("Completed Tasks by Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    
                    Chart(energy.taskTypeCounts.sorted(by: { $0.value > $1.value }), id: \.key) { item in
                        SectorMark(
                            angle: .value("Count", item.value),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value("Category", item.key.title))
                        .cornerRadius(4)
                    }
                    .frame(height: 200)
                    .chartLegend(position: .bottom, alignment: .center)
                }
			}
		}
	}
}
