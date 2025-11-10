import Foundation

@MainActor
final class MoodStatisticsViewModel: ObservableObject {

    // MARK: - Helper
    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    // MARK: - Structs
    struct MoodSummary {
        let lastMood: Int
        let delta: Int
        let averageToday: Double
        let averagePastWeek: Double
        let uniqueDayCount: Int
        let entriesCount: Int
        let trend: TrendDirection
        let comment: String

        static let empty = MoodSummary(
            lastMood: 0,
            delta: 0,
            averageToday: 0,
            averagePastWeek: 0,
            uniqueDayCount: 0,
            entriesCount: 0,
            trend: .flat,
            comment: ""
        )
    }

    // MARK: - Mood Summary
    func moodSummary(entries: [MoodEntry]) -> MoodSummary? {
        guard !entries.isEmpty else { return nil }

        let cal = TimeZoneManager.shared.calendar
        let now = Date()
        let startDate = cal.startOfDay(for: cal.date(byAdding: .day, value: -(7 - 1), to: now)!)

        // Sort by date to find last and delta
        let sorted = entries.sorted { $0.date < $1.date }
        guard let last = sorted.last else { return nil }

        var delta = 0
        if sorted.count >= 2 {
            let prev = sorted[sorted.count - 2]
            delta = last.value - prev.value
        }

        var totalToday = 0
        var countToday = 0
        var allDays = Set<Date>()

        for entry in entries {
            let day = cal.startOfDay(for: entry.date)
            allDays.insert(day)
            if cal.isDate(entry.date, inSameDayAs: now) {
                totalToday += entry.value
                countToday += 1
            }
        }

        let avgToday = countToday > 0 ? rounded(Double(totalToday) / Double(countToday)) : 0.0

        // Past week average as mean of per-day averages
        let weekEntries = entries.filter { $0.date >= startDate }
        var daySums: [Date: (sum: Int, count: Int)] = [:]
        for e in weekEntries {
            let day = cal.startOfDay(for: e.date)
            var item = daySums[day] ?? (0, 0)
            item.sum += e.value
            item.count += 1
            daySums[day] = item
        }
        let dayAverages = daySums.values.map { Double($0.sum) / Double(max(1, $0.count)) }
        let avgWeek = dayAverages.isEmpty ? 0.0 : rounded(dayAverages.reduce(0.0, +) / Double(dayAverages.count))

        let trend: TrendDirection = avgToday > avgWeek ? .up : (avgToday < avgWeek ? .down : .flat)
        let comment: String = {
            switch trend {
            case .up: return "太好了，最近有在好好生活！"
            case .down: return "最近情绪略有下降，试着放松一下吧！"
            case .flat: return "最近情绪稳定，继续保持～"
            }
        }()

        return MoodSummary(
            lastMood: last.value,
            delta: delta,
            averageToday: avgToday,
            averagePastWeek: avgWeek,
            uniqueDayCount: allDays.count,
            entriesCount: entries.count,
            trend: trend,
            comment: comment
        )
    }
}
