struct EnergyTrendSection: View {
	let energyHistory: [EnergyHistoryEntry]

	var body: some View {
		DashboardCard(title: "能量趋势（近14天）", icon: "chart.line.uptrend.xyaxis") {
			Chart(energyHistory.suffix(14)) { entry in
				LineMark(
					x: .value("日期", entry.date),
					y: .value("能量", entry.totalEnergy)
				)
				PointMark(
					x: .value("日期", entry.date),
					y: .value("能量", entry.totalEnergy)
				)
			}
			.frame(height: 180)
		}
	}
}
