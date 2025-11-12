import SwiftUI

struct MoodStatsSection: View {
    let mood: MoodStatisticsViewModel.MoodSummary

    var body: some View {
        DashboardCard(title: "情绪摘要", icon: "face.smiling") {
            VStack(alignment: .leading, spacing: 8) {
                // 最新情绪 + 趋势
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("最新情绪：")
                        .font(.title2.weight(.semibold))
                    Text("\(mood.lastMood)")
						.font(.title2.weight(.bold))
                    if !mood.trend.rawValue.isEmpty {
                        Image(systemName: mood.trend.rawValue)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                // 平均值显示
				Divider().padding(.vertical, 6)
				
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("今日平均")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
						Text("\(mood.averageToday)")
							.font(.title2.weight(.medium))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("过去一周平均")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(mood.averagePastWeek)")
                            .font(.title2.weight(.medium))
                    }
                }

                // 累计记录
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("记录天数")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(mood.uniqueDayCount)")
                            .font(.title2.weight(.medium))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("累计记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(mood.entriesCount)")
                            .font(.title2.weight(.medium))
                    }
                }

                // 心情评论
                Text(mood.comment.isEmpty ? "暂无情绪总结" : mood.comment)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }
}
