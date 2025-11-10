import Foundation

@MainActor
final class EnergyStatisticsViewModel: ObservableObject {
    struct EnergySummary {
        let lastEnergy: Int
        let delta: Int
        let todayAdd: Int
        let todayDeduct: Int
        let todayDelta: Int
        let averageDailyAddPastWeek: Double
        let averageDailyUsePastWeek: Double
        let averageToday: Double
        let averagePastWeek: Double
        let trend: TrendDirection
        let comment: String

        static let empty = EnergySummary(
            lastEnergy: 0,
            delta: 0,
            todayAdd: 0,
            todayDeduct: 0,
            todayDelta: 0,
            averageDailyAddPastWeek: 0,
            averageDailyUsePastWeek: 0,
            averageToday: 0,
            averagePastWeek: 0,
            trend: .flat,
            comment: ""
        )
    }

    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    func energySummary(
        from history: [EnergyHistoryEntry],
        metrics: [DailyActivityMetrics]? = nil,
        days: Int = 7
    ) -> EnergySummary? {
        guard !history.isEmpty,
              let last = history.max(by: { $0.date < $1.date }) else { return nil }

        let calendar = TimeZoneManager.shared.calendar
        let now = Date()
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: now)!)

        let sorted = history.sorted { $0.date < $1.date }
        let previousEntry = sorted.dropLast().last
        let delta = last.totalEnergy - (previousEntry?.totalEnergy ?? last.totalEnergy)

        var todayAdd = 0
        var todayDeduct = 0
        var totalToday = 0
        var countToday = 0
        var previousEnergy: Int?

        for entry in sorted where calendar.isDate(entry.date, inSameDayAs: now) {
            totalToday += entry.totalEnergy
            countToday += 1
            if let previous = previousEnergy {
                let difference = entry.totalEnergy - previous
                if difference > 0 {
                    todayAdd += difference
                } else {
                    todayDeduct -= difference
                }
            }
            previousEnergy = entry.totalEnergy
        }

        let todayDelta = todayAdd - todayDeduct
        let averageToday = countToday > 0 ? rounded(Double(totalToday) / Double(countToday)) : 0.0

        var addPerDay = [Date: Int]()
        var usePerDay = [Date: Int]()
        var sumPerDay = [Date: (total: Int, count: Int)]()
        previousEnergy = nil

        for entry in sorted where entry.date >= startDate {
            let day = calendar.startOfDay(for: entry.date)
            if let previous = previousEnergy {
                let difference = entry.totalEnergy - previous
                if difference > 0 {
                    addPerDay[day, default: 0] += difference
                } else {
                    usePerDay[day, default: 0] += abs(difference)
                }
            }

            var bucket = sumPerDay[day] ?? (0, 0)
            bucket.total += entry.totalEnergy
            bucket.count += 1
            sumPerDay[day] = bucket
            previousEnergy = entry.totalEnergy
        }

        let dayCount = sumPerDay.count
        let averageAddWeek = dayCount > 0 ? rounded(Double(addPerDay.values.reduce(0, +)) / Double(dayCount)) : 0.0
        let averageUseWeek = dayCount > 0 ? rounded(Double(usePerDay.values.reduce(0, +)) / Double(dayCount)) : 0.0
        let averageWeek = dayCount > 0
            ? rounded(sumPerDay.values.reduce(0.0) { $0 + Double($1.total) / Double($1.count) } / Double(dayCount))
            : 0.0

        var score = averageToday > averageWeek ? 1 : (averageToday < averageWeek ? -1 : 0)
        if let metrics {
            let metricsByDay = Dictionary(uniqueKeysWithValues: metrics.map { (calendar.startOfDay(for: $0.date), $0) })
            let daysSorted = Array(sumPerDay.keys).sorted()
            let midpoint = daysSorted.count / 2
            var firstHalfTasks = 0
            var secondHalfTasks = 0
            var firstHalfInteractions = 0
            var secondHalfInteractions = 0
            for (index, day) in daysSorted.enumerated() {
                guard let metric = metricsByDay[day] else { continue }
                if index < midpoint {
                    firstHalfTasks += metric.completedTaskCount
                    firstHalfInteractions += metric.petInteractionCount
                } else {
                    secondHalfTasks += metric.completedTaskCount
                    secondHalfInteractions += metric.petInteractionCount
                }
            }
            if secondHalfTasks > firstHalfTasks { score += 1 }
            else if secondHalfTasks < firstHalfTasks { score -= 1 }
            if secondHalfInteractions > firstHalfInteractions { score += 1 }
            else if secondHalfInteractions < firstHalfInteractions { score -= 1 }
        }
        let trend: TrendDirection = score > 0 ? .up : (score < 0 ? .down : .flat)

        let comment: String = {
            var parts: [String] = []
            switch trend {
            case .up: parts.append("最近能量在上升，做得很棒！")
            case .down: parts.append("最近能量略有下降，注意休息恢复哦。")
            case .flat: parts.append("能量水平保持稳定。")
            }
            parts.append("今日 +\(todayAdd) / -\(todayDeduct)")
            if let metrics {
                let totalTasks = metrics.reduce(0) { $0 + $1.completedTaskCount }
                let totalInteractions = metrics.reduce(0) { $0 + $1.petInteractionCount }
                parts.append("近\(days)天完成任务 \(totalTasks) 次，互动 \(totalInteractions) 次")
            }
            return parts.joined(separator: " · ")
        }()

        return EnergySummary(
            lastEnergy: last.totalEnergy,
            delta: delta,
            todayAdd: todayAdd,
            todayDeduct: todayDeduct,
            todayDelta: todayDelta,
            averageDailyAddPastWeek: averageAddWeek,
            averageDailyUsePastWeek: averageUseWeek,
            averageToday: averageToday,
            averagePastWeek: averageWeek,
            trend: trend,
            comment: comment
        )
    }
}
