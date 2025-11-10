import Foundation

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
    struct RhythmBreakdown: Equatable {
        var timeSlot: [TimeSlot: Double]
        var weather: [WeatherType: Double]
        var dayPeriod: [DayPeriod: Double]
        var daylightHint: String

        static let empty = RhythmBreakdown(
            timeSlot: [:],
            weather: [:],
            dayPeriod: [:],
            daylightHint: "暂无足够数据用于日照关联分析。"
        )
    }

    @Published private(set) var latestBreakdown: RhythmBreakdown = .empty

    private let calendar = TimeZoneManager.shared.calendar

    @discardableResult
    func rhythmAnalysis(for entries: [MoodEntry], tasks: [Task]) -> RhythmBreakdown {
        let slotAverages = timeSlotMoodAverages(entries: entries)
        let breakdown = RhythmBreakdown(
            timeSlot: slotAverages,
            weather: weatherMoodAverages(entries: entries, tasks: tasks),
            dayPeriod: daylightMoodAverages(entries: entries),
            daylightHint: daylightCorrelationText(slotAverages: slotAverages)
        )
        latestBreakdown = breakdown
        return breakdown
    }

    private func timeSlotMoodAverages(entries: [MoodEntry]) -> [TimeSlot: Double] {
        guard !entries.isEmpty else { return [:] }
        var accumulator: [TimeSlot: (sum: Int, count: Int)] = [:]
        for entry in entries {
            let slot = TimeSlot.from(date: entry.date, using: calendar)
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

    private func weatherMoodAverages(entries: [MoodEntry], tasks: [Task]) -> [WeatherType: Double] {
        guard !entries.isEmpty else { return [:] }

        let dayGroups = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let dayAverages = dayGroups.mapValues { group -> Double in
            let total = group.reduce(0) { $0 + $1.value }
            return Double(total) / Double(group.count)
        }

        guard !dayAverages.isEmpty else { return [:] }

        let tasksByDay = Dictionary(grouping: tasks) { calendar.startOfDay(for: $0.date) }

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

    private func dominantWeather(for tasks: [Task]?) -> WeatherType? {
        guard let tasks, !tasks.isEmpty else { return nil }
        let counts = tasks.reduce(into: [WeatherType: Int]()) { partial, task in
            partial[task.weatherType, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func daylightCorrelationText(slotAverages: [TimeSlot: Double]) -> String {
        guard !slotAverages.isEmpty else { return RhythmBreakdown.empty.daylightHint }
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

    private func daylightMoodAverages(entries: [MoodEntry]) -> [DayPeriod: Double] {
        guard !entries.isEmpty else { return [:] }
        var accumulator: [DayPeriod: (sum: Int, count: Int)] = [:]
        for entry in entries {
            let slot = TimeSlot.from(date: entry.date, using: calendar)
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
