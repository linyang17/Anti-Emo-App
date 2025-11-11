import Foundation
import Combine

enum DayPeriod: String, CaseIterable, Identifiable, Sendable {
    case daylight
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daylight: return "日间"
        case .night: return "夜间"
        }
    }
}

@MainActor
final class StatisticsAnalysisViewModel: ObservableObject {
    private let cal: Calendar = TimeZoneManager.shared.calendar

    // MARK: - Published Outputs (optional for UI binding)
    @Published var timeSlotAverages: [TimeSlot: Double] = [:]
    @Published var weatherAverages: [WeatherType: Double] = [:]
    @Published var daylightHint: String = ""
    @Published var dayPeriodAverages: [DayPeriod: Double] = [:]

    // MARK: - Unified Wrapper Function
    func rhythmAnalysis(for entries: [MoodEntry], tasks: [UserTask]) -> (
        timeSlot: [TimeSlot: Double],
        weather: [WeatherType: Double],
        daylight: String,
        dayPeriod: [DayPeriod: Double]
    ) {
        let slot = timeSlotMoodAverages(entries: entries)
        let weather = weatherMoodAverages(entries: entries, tasks: tasks)
        let daylightBuckets = daylightMoodAverages(entries: entries)
        let text = daylightCorrelationText(slotAverages: slot)

        timeSlotAverages = slot
        weatherAverages = weather
        dayPeriodAverages = daylightBuckets
        daylightHint = text

        return (slot, weather, text, daylightBuckets)
    }

    // 1) 时段分析：上午 vs 下午 vs 晚上平均情绪
    func timeSlotMoodAverages(entries: [MoodEntry]) -> [TimeSlot: Double] {
        guard !entries.isEmpty else { return [:] }

        var accumulator: [TimeSlot: (sum: Int, count: Int)] = [:]
        for entry in entries {
            let slot = TimeSlot.from(date: entry.date, using: cal)
            var bucket = accumulator[slot] ?? (0, 0)
            bucket.sum += entry.value
            bucket.count += 1
            accumulator[slot] = bucket
        }

        return accumulator.reduce(into: [:]) { partial, element in
            let (slot, bucket) = element
            guard bucket.count > 0 else { return }
            partial[slot] = Double(bucket.sum) / Double(bucket.count)
        }
    }

    private func weatherMoodAverages(entries: [MoodEntry], tasks: [UserTask]) -> [WeatherType: Double] {
        guard !entries.isEmpty else { return [:] }

        let dayGroups = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        let dayAverages = dayGroups.mapValues { group -> Double in
            let total = group.reduce(0) { $0 + $1.value }
            return Double(total) / Double(group.count)
        }

        guard !dayAverages.isEmpty else { return [:] }

        let tasksByDay = Dictionary(grouping: tasks) { cal.startOfDay(for: $0.date) }

        var accumulator: [WeatherType: (sum: Double, count: Int)] = [:]
        for (day, average) in dayAverages {
            guard let dominantWeather = dominantWeather(for: tasksByDay[day]) else { continue }
            var bucket = accumulator[dominantWeather] ?? (0, 0)
            bucket.sum += average
            bucket.count += 1
            accumulator[dominantWeather] = bucket
        }

        return accumulator.reduce(into: [:]) { result, element in
            let (weather, bucket) = element
            guard bucket.count > 0 else { return }
            result[weather] = bucket.sum / Double(bucket.count)
        }
    }

    private func dominantWeather(for tasks: [UserTask]?) -> WeatherType? {
        guard let tasks, !tasks.isEmpty else { return nil }
        let counts = tasks.reduce(into: [WeatherType: Int]()) { partial, task in
            partial[task.weatherType, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func daylightCorrelationText(slotAverages: [TimeSlot: Double]) -> String {
        guard !slotAverages.isEmpty else { return "暂无足够的数据来生成日照提示。" }

        if let (slot, _) = slotAverages.min(by: { $0.value < $1.value }) {
            switch slot {
            case .morning:
                return "上午时段的情绪平均偏低。可以考虑晒晒太阳或安排一杯热饮来开启一天。"
            case .afternoon:
                return "下午时段的情绪平均偏低。试着外出走走或做个轻运动，转换一下状态。"
            case .evening:
                return "傍晚时段的情绪平均偏低。安排一点放松活动，帮助过渡到夜间休息。"
            case .night:
                return "夜间时段的情绪平均偏低。试着提前一点休息，减少屏幕时间，改善睡眠质量。"
            }
        }

        return "各时段情绪较为均衡，暂无明显日照相关的波动。"
    }

    // 日间平均情绪
    private func daylightMoodAverages(entries: [MoodEntry]) -> [DayPeriod: Double] {
        guard !entries.isEmpty else { return [:] }

        var accumulator: [DayPeriod: (sum: Int, count: Int)] = [:]
        for entry in entries {
            let slot = TimeSlot.from(date: entry.date, using: cal)
            let period: DayPeriod = switch slot {
            case .morning, .afternoon: .daylight
            case .evening, .night: .night
            }

            var bucket = accumulator[period] ?? (0, 0)
            bucket.sum += entry.value
            bucket.count += 1
            accumulator[period] = bucket
        }

        return accumulator.reduce(into: [:]) { partial, element in
            let (period, bucket) = element
            guard bucket.count > 0 else { return }
            partial[period] = Double(bucket.sum) / Double(bucket.count)
        }
    }
}
