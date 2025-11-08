import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter
    }()

    func completionSummary(rate: Double, totalTasks: Int) -> String {
        let percent = StatisticsViewModel.percentFormatter.string(from: NSNumber(value: rate)) ?? "0%"
        return "\(percent) · \(totalTasks) 项"
    }

    func streakSummary(for stats: UserStats?) -> String {
        guard let stats else { return "暂无连续签到" }
        let dayString = stats.streakDays > 0 ? "\(stats.streakDays) 天" : "未开始"
        return "连击：\(dayString)"
    }

    func energyDeltaDescription(from history: [EnergyHistoryEntry]) -> String? {
        guard let latest = history.last else { return nil }
        guard let previous = history.dropLast().last else {
            return "今日记录于 \(StatisticsViewModel.dateFormatter.string(from: latest.date))"
        }
        let delta = latest.totalEnergy - previous.totalEnergy
        let prefix = delta >= 0 ? "+" : ""
        return "较昨日 \(prefix)\(delta)"
    }

    func recentMoodAverage(entries: [MoodEntry]) -> String? {
        let recent = Array(entries.prefix(5))
        guard !recent.isEmpty else { return nil }
        let sum = recent.reduce(0) { $0 + $1.value }
        let average = Double(sum) / Double(recent.count)
        return "近 \(recent.count) 次平均：\(Int(average))"
    }
}
