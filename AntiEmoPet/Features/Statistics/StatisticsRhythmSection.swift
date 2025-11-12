import SwiftUI
import Charts
import Combine

struct StatisticsRhythmSection: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var analysis = StatisticsAnalysisViewModel()

    var body: some View {
        VStack(spacing: 16) {
            DashboardCard(title: "情绪时段分析", icon: "clock") {
                rhythmSlotChart(data: analysis.timeSlotAverages)
            }

            DashboardCard(title: "天气关联度", icon: "cloud.sun") {
                rhythmWeatherChart(data: analysis.weatherAverages)
            }

            DashboardCard(title: "日照关联度", icon: "sun.max") {
                rhythmDaylightView(buckets: analysis.dayPeriodAverages, hint: analysis.daylightHint)
            }
        }
        .onAppear(perform: refreshRhythms)
        .onReceive(appModel.$moodEntries) { _ in refreshRhythms() }
        .onReceive(appModel.$todayTasks) { _ in refreshRhythms() }
    }

    private func refreshRhythms() {
        analysis.rhythmAnalysis(for: appModel.moodEntries, tasks: appModel.allTasks)
    }

    @ViewBuilder
    private func rhythmSlotChart(data: [TimeSlot: Double]) -> some View {
        if data.isEmpty {
            rhythmPlaceholder(systemImage: "clock")
        } else {
            let ordered = TimeSlot.allCases.compactMap { slot -> SlotAverage? in
                guard let value = data[slot] else { return nil }
                return SlotAverage(slot: slot, value: value)
            }
            if ordered.isEmpty {
                rhythmPlaceholder(systemImage: "clock")
            } else {
                Chart(ordered) { item in
                    BarMark(
                        x: .value("平均情绪", item.value),
                        y: .value("时段", item.slot.localizedTitle)
                    )
                    .foregroundStyle(.purple.gradient)
                }
                .chartXAxis { AxisMarks(position: .bottom) }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 160)
            }
        }
    }

    @ViewBuilder
    private func rhythmWeatherChart(data: [WeatherType: Double]) -> some View {
        if data.isEmpty {
            rhythmPlaceholder(systemImage: "cloud.sun")
        } else {
            let ordered = WeatherType.allCases.compactMap { type -> WeatherAverage? in
                guard let value = data[type] else { return nil }
                return WeatherAverage(type: type, value: value)
            }
            if ordered.isEmpty {
                rhythmPlaceholder(systemImage: "cloud.sun")
            } else {
                Chart(ordered) { item in
                    LineMark(
                        x: .value("天气", item.type.title),
                        y: .value("平均情绪", item.value)
                    )
                    PointMark(
                        x: .value("天气", item.type.title),
                        y: .value("平均情绪", item.value)
                    )
                    .symbol(by: .value("天气", item.type.title))
                }
                .chartXAxis { AxisMarks(values: ordered.map { $0.type.title }) }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 160)
            }
        }
    }

    @ViewBuilder
    private func rhythmDaylightView(buckets: [DayPeriod: Double], hint: String) -> some View {
        if buckets.isEmpty {
            VStack(alignment: .center, spacing: 8) {
                rhythmPlaceholder(systemImage: "sun.max")
                if !hint.isEmpty {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            let ordered = DayPeriod.allCases.compactMap { period -> DaylightAverage? in
                guard let value = buckets[period] else { return nil }
                return DaylightAverage(period: period, value: value)
            }
            if ordered.isEmpty {
                rhythmPlaceholder(systemImage: "sun.max")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Chart(ordered) { item in
                        BarMark(
                            x: .value("情绪", item.value),
                            y: .value("时段", item.period.title)
                        )
                        .foregroundStyle(.orange.gradient)
                        .cornerRadius(6)
                    }
                    .chartXAxis { AxisMarks(position: .bottom) }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .frame(height: 140)

                    if !hint.isEmpty {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rhythmPlaceholder(systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("暂无数据")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("记录更多情绪后可查看该图表")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private struct SlotAverage: Identifiable {
    let slot: TimeSlot
    let value: Double

    var id: String { slot.rawValue }
}

private struct WeatherAverage: Identifiable {
    let type: WeatherType
    let value: Double

    var id: String { type.rawValue }
}

private struct DaylightAverage: Identifiable {
    let period: DayPeriod
    let value: Double

    var id: String { period.rawValue }
}

private extension TimeSlot {
    var localizedTitle: String {
        switch self {
        case .morning: return "早晨"
        case .afternoon: return "下午"
        case .evening: return "傍晚"
        case .night: return "夜间"
        }
    }
}
