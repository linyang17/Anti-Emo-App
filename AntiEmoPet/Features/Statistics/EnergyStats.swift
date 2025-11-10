import SwiftUI

struct EnergyStatsSection: View {
        let energy: EnergyStatisticsViewModel.EnergySummary

        var body: some View {
                DashboardCard(title: "能量摘要 / Energy Stats", icon: "bolt.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text("今日平均能量：\(String(format: "%.1f", energy.averageToday))")
                                                .font(.title3.weight(.semibold))

                                        Image(systemName: energy.trend.rawValue)
                                                .font(.headline)
                                                .foregroundStyle(.secondary)
                                                .accessibilityLabel(energy.trend.accessibilityLabel)
                                }

                                Text("过去7天平均：\(String(format: "%.1f", energy.averagePastWeek))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                                Text("今日补充")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                Text("+\(energy.todayAdd)")
                                                        .font(.subheadline.weight(.medium))
                                        }

                                        Spacer(minLength: 24)

                                        VStack(alignment: .leading, spacing: 4) {
                                                Text("今日消耗")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                Text("-\(energy.todayDeduct)")
                                                        .font(.subheadline.weight(.medium))
                                        }
                                }

                                Text(energy.comment.isEmpty ? "暂无补充说明" : energy.comment)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                }
        }
}
