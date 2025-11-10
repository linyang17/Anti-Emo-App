import SwiftUI
import Charts

struct MoodTrendSection: View {
        @EnvironmentObject private var appModel: AppViewModel
        @State private var window: Int = 14

        var body: some View {
                DashboardCard(title: "情绪趋势", icon: "face.smiling") {
                        VStack(alignment: .leading, spacing: 12) {
                                Picker("窗口", selection: $window) {
                                        Text("7天").tag(7)
                                        Text("14天").tag(14)
                                        Text("30天").tag(30)
                                }
                                .pickerStyle(.segmented)

                                let data = dailyMoodAverages(windowDays: window)
                                if data.isEmpty {
                                        Text("暂无数据")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 160)
                                } else {
                                        Chart(data) { point in
                                                LineMark(
                                                        x: .value("日期", point.date),
                                                        y: .value("平均情绪", point.average)
                                                )
                                                PointMark(
                                                        x: .value("日期", point.date),
                                                        y: .value("平均情绪", point.average)
                                                )
                                                .foregroundStyle(.blue)
                                        }
                                        .chartXAxis {
                                                AxisMarks(values: .stride(by: .day)) { value in
                                                        AxisValueLabel {
                                                                if let date = value.as(Date.self) {
                                                                        Text(date, format: .dateTime.month().day())
                                                                }
                                                        }
                                                }
                                        }
                                        .chartYAxis {
                                                AxisMarks(position: .leading)
                                        }
                                        .frame(height: 180)
                                }
                        }
                }
        }

        private func dailyMoodAverages(windowDays: Int) -> [MoodTrendPoint] {
                guard !appModel.moodEntries.isEmpty else { return [] }
                let calendar = TimeZoneManager.shared.calendar
                let now = calendar.startOfDay(for: Date())
                let start = calendar.date(byAdding: .day, value: -(max(1, windowDays) - 1), to: now) ?? now

                var sums: [Date: (sum: Int, count: Int)] = [:]
                for entry in appModel.moodEntries where entry.date >= start {
                        let day = calendar.startOfDay(for: entry.date)
                        var item = sums[day] ?? (0, 0)
                        item.sum += entry.value
                        item.count += 1
                        sums[day] = item
                }

                return sums.compactMap { key, value in
                        guard value.count > 0 else { return nil }
                        let avg = Double(value.sum) / Double(value.count)
                        return MoodTrendPoint(date: key, average: avg)
                }
                .sorted(by: { $0.date < $1.date })
        }
}

private struct MoodTrendPoint: Identifiable {
        let date: Date
        let average: Double

        var id: Date { date }
}
