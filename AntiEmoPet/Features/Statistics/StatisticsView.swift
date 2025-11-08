import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DashboardCard(title: "当前能量", icon: "bolt.fill") {
                    Text("\(appModel.totalEnergy)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    if let delta = viewModel.energyDeltaDescription(from: appModel.energyHistory) {
                        Text(delta)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                DashboardCard(title: "今日完成率", icon: "checklist") {
                    Text(viewModel.completionSummary(rate: appModel.completionRate, totalTasks: appModel.todayTasks.count))
                        .font(.title3.weight(.semibold))
                    ProgressView(value: appModel.completionRate)
                        .tint(.green)
                }

                DashboardCard(title: "连击记录", icon: "flame.fill") {
                    Text(viewModel.streakSummary(for: appModel.userStats))
                        .font(.title3.weight(.semibold))
                    if let lastActive = appModel.userStats?.lastActiveDate {
                        Text("最近活跃：\(lastActive.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !appModel.energyHistory.isEmpty {
                    DashboardCard(title: "能量趋势", icon: "chart.line.uptrend.xyaxis") {
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

                if let moodSummary = viewModel.recentMoodAverage(entries: appModel.moodEntries) {
                    DashboardCard(title: "心情摘要", icon: "face.smiling") {
                        Text(moodSummary)
                            .font(.title3.weight(.semibold))
                        if let latest = appModel.moodEntries.first {
                            Text("最新记录：\(latest.value) · \(latest.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Statistics")
        .energyToolbar(appModel: appModel)
    }
}
