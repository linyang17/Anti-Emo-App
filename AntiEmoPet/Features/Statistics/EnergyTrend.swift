import SwiftUI
import Charts


struct EnergyTrendSection: View {
    @State private var window: Int = 14
    let energyHistory: [EnergyHistoryEntry]

    var body: some View {
        DashboardCard(title: "能量趋势", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("窗口", selection: $window) {
                    Text("7天").tag(7)
                    Text("14天").tag(14)
                    Text("30天").tag(30)
                }
                .pickerStyle(.segmented)

                let data = dailyAdded(windowDays: window)
                if data.isEmpty {
                    ContentUnavailableView("暂无数据", systemImage: "chart.line.uptrend.xyaxis", description: Text("记录能量补充后可以看到趋势变化"))
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    Chart(data.sorted(by: { $0.key < $1.key }), id: \.key) { day, added in
                        LineMark(
                            x: .value("日期", day),
                            y: .value("每日补充", added)
                        )
                        PointMark(
                            x: .value("日期", day),
                            y: .value("每日补充", added)
                        )
                        .foregroundStyle(.green)
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

    private func dailyAdded(windowDays: Int) -> [Date: Int] {
        guard !energyHistory.isEmpty else { return [:] }
        let cal = TimeZoneManager.shared.calendar
        let sorted = energyHistory.sorted { $0.date < $1.date }
        let now = Date()
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(max(1, windowDays) - 1), to: now)!)

        var result: [Date: Int] = [:]
        var prev: EnergyHistoryEntry? = nil
        for entry in sorted where entry.date >= start {
            if let p = prev {
                let diff = entry.totalEnergy - p.totalEnergy
                if diff > 0 {
                    let day = cal.startOfDay(for: entry.date)
                    result[day, default: 0] += diff
                }
            }
            prev = entry
        }
        return result
    }
}
