import SwiftUI
import Charts

struct StatisticsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var viewModel = StatisticsViewModel()

	var body: some View {
		ScrollView {
			VStack(spacing: 20) {

				// 🧩 当前心情模块
				DashboardCard(title: "当前心情", icon: "heart.fill") {
					if let mood = viewModel.moodSummary(entries: appModel.moodEntries) {
						VStack(spacing: 8) {
							Text("最新情绪：\(mood.lastMood) (\(mood.delta >= 0 ? "+" : "")\(mood.delta)) \(mood.trend.rawValue)")
								.font(.system(size: 48, weight: .bold, design: .rounded))
							Text("今日平均：\(mood.averageToday) · 过去7天：\(mood.averagePastWeek)")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text(mood.insight)
								.font(.footnote)
								.foregroundStyle(.secondary)
							Text("总共记录：\(mood.uniqueDayCount) 天，\(mood.entriesCount) 条情绪")
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
					} else {
						Text("暂无情绪记录")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
				
				// ⚡ 能量模块
				if let energy = viewModel.energySummary(from: appModel.energyHistory) {
					DashboardCard(title: "能量摘要", icon: "bolt.fill") {
						VStack(spacing: 8) {
							Text("最新能量：\(energy.lastEnergy) (\(energy.delta >= 0 ? "+" : "")\(energy.delta)) \(energy.trend.rawValue)")
								.font(.title3.weight(.semibold))
							Text("今日平均：\(energy.averageToday) · 过去7天：\(energy.averagePastWeek)")
								.font(.subheadline)
								.foregroundStyle(.secondary)
							Text(energy.insight)
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
					}
				}

				// 📊 能量趋势图 with mean line
				if !appModel.energyHistory.isEmpty {
					DashboardCard(title: "能量趋势图", icon: "chart.line.uptrend.xyaxis") {
						Chart(appModel.energyHistory.suffix(14)) { entry in
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
			.padding()
		}
		.navigationTitle("统计")
		.energyToolbar(appModel: appModel)
	}
}
