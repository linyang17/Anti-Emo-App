import SwiftUI

struct MoodStatsSection: View {
    let mood: MoodStatisticsViewModel.MoodSummary

    var body: some View {
        DashboardCard(title: "情绪摘要", icon: "smile.fill") {
            VStack(alignment: .leading, spacing: 8) {
                // 最新情绪 + 趋势
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("最新情绪：")
                        .font(.title3.weight(.semibold))
                    Text("\(mood.lastMood)")
                        .font(.title3.weight(.bold))
                    if !mood.trend.rawValue.isEmpty {
                        Image(systemName: mood.trend.rawValue)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                // 平均值显示
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日平均")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", mood.averageToday))
                            .font(.subheadline.weight(.medium))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("过去一周平均")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f", mood.averagePastWeek))
                            .font(.subheadline.weight(.medium))
                    }
                }

                // 累计记录
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计打卡天数")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(mood.uniqueDayCount)")
                            .font(.subheadline.weight(.medium))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("累计记录次数")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(mood.entriesCount)")
                            .font(.subheadline.weight(.medium))
                    }
                }

                // 心情评论
                Divider().padding(.vertical, 6)
                Text(mood.comment.isEmpty ? "暂无情绪总结" : mood.comment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}
