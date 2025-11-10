import SwiftUI
import Charts

struct StatisticsRhythmSection: View {
        @EnvironmentObject private var appModel: AppViewModel
        @StateObject private var analysis = StatisticsAnalysisViewModel()

        var body: some View {
                let entries = appModel.moodEntries
                let tasks = appModel.allTasks
                let result = analysis.rhythmAnalysis(for: entries, tasks: tasks)

                return VStack(spacing: 16) {
                        DashboardCard(title: "情绪节律 · 时段", icon: "clock") {
                                rhythmSlotChart(data: result.timeSlot)
                        }

                        DashboardCard(title: "情绪节律 · 天气", icon: "cloud.sun") {
                                rhythmWeatherChart(data: result.weather)
                        }

                        DashboardCard(title: "情绪节律 · 日照提示", icon: "sun.max") {
                                rhythmDaylightView(buckets: result.dayPeriod, hint: result.daylight)
                        }
                }
        }

        @ViewBuilder
        private func rhythmSlotChart(data: [TimeSlot: Double]) -> some View {
                if data.isEmpty {
                        rhythmPlaceholder()
                } else {
                        let ordered = TimeSlot.allCases.compactMap { slot -> SlotAverage? in
                                guard let value = data[slot] else { return nil }
                                return SlotAverage(slot: slot, value: value)
                        }
                        if ordered.isEmpty {
                                rhythmPlaceholder()
                        } else {
                                Chart(ordered) { item in
                                        BarMark(
                                                x: .value("平均情绪", item.value),
                                                y: .value("时段", item.slot.localizedTitle)
                                        )
                                        .foregroundStyle(.purple.gradient)
                                }
                                .chartXAxis {
                                        AxisMarks(position: .bottom)
                                }
                                .chartYAxis {
                                        AxisMarks(position: .leading)
                                }
                                .frame(height: 160)
                        }
                }
        }

        @ViewBuilder
        private func rhythmWeatherChart(data: [WeatherType: Double]) -> some View {
                if data.isEmpty {
                        rhythmPlaceholder()
                } else {
                        let ordered = WeatherType.allCases.compactMap { type -> WeatherAverage? in
                                guard let value = data[type] else { return nil }
                                return WeatherAverage(type: type, value: value)
                        }
                        if ordered.isEmpty {
                                rhythmPlaceholder()
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
                                .chartXAxis {
                                        AxisMarks(values: ordered.map { $0.type.title })
                                }
                                .chartYAxis {
                                        AxisMarks(position: .leading)
                                }
                                .frame(height: 160)
                        }
                }
        }

        @ViewBuilder
        private func rhythmDaylightView(buckets: [DayPeriod: Double], hint: String) -> some View {
                if buckets.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                                rhythmPlaceholder()
                                Text(hint)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                        }
                } else {
                        let ordered = DayPeriod.allCases.compactMap { period -> DaylightAverage? in
                                guard let value = buckets[period] else { return nil }
                                return DaylightAverage(period: period, value: value)
                        }
                        if ordered.isEmpty {
                                rhythmPlaceholder()
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
                                        .chartXAxis {
                                                AxisMarks(position: .bottom)
                                        }
                                        .chartYAxis {
                                                AxisMarks(position: .leading)
                                        }
                                        .frame(height: 140)

                                        Text(hint)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                }
                        }
                }
        }

        @ViewBuilder
        private func rhythmPlaceholder() -> some View {
                Text("暂无数据")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
