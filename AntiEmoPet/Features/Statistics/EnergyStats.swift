struct EnergyStats: View {
	let energy: StatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "能量摘要 / Energy Stats", icon: "bolt.fill") {
			VStack(alignment: .leading, spacing: 8) {
				Text("今日平均能量：\(energy.averageToday) \(energy.trendText)")
					.font(.title3.weight(.semibold))

				Text("过去7天平均：\(energy.averageAddPastWeek)")
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

					Spacer()

					VStack(alignment: .leading, spacing: 2) {
						Text("今日净变化")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("\(energy.todayDelta >= 0 ? "+" : "")\(energy.todayDelta)")
							.font(.subheadline.weight(.semibold))
							.foregroundStyle(energy.todayDelta >= 0 ? .green : .red)
					}
				}

				Text(energy.insight)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		}
	}
}