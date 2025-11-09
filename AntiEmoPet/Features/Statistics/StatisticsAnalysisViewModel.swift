import Foundation

@MainActor
final class StatisticsAnalysisViewModel: ObservableObject {
	
    private let cal: Calendar = TimeZoneManager.shared.calendar

	// MARK: - Published Outputs (optional for UI binding)
	@Published var timeSlotAverages: [TimeSlot: Double] = [:]
	@Published var weatherAverages: [WeatherType: Double] = [:]
	@Published var daylightHint: String = ""

	// MARK: - Unified Wrapper Function
	func rhythmAnalysis(for entries: [MoodEntry], tasks: [Task]) -> (timeSlot: [TimeSlot: Double], weather: [WeatherType: Double], daylight: String) {
		let slot = timeSlotMoodAverages(entries: entries)
		let weather = weatherMoodAverages(entries: entries, tasks: tasks)
		let text = daylightCorrelationText(entries: entries)
		return (slot, weather, text)
	}

    // 1) 时段分析：上午 vs 下午 vs 晚上平均情绪
    func timeSlotMoodAverages(entries: [MoodEntry]) -> [TimeSlot: Double] {
        guard !entries.isEmpty else { return [:] }
        var acc: [TimeSlot: (sum: Int, count: Int)] = [:]
        for e in entries {
            let slot = TimeSlot.from(date: e.date, using: cal)
            var item = acc[slot] ?? (0, 0)
            item.sum += e.value
            item.count += 1
            acc[slot] = item
        }
        var result: [TimeSlot: Double] = [:]
        for (slot, item) in acc {
            result[slot] = Double(item.sum) / Double(max(1, item.count))
        }
        return result
    }

    // 2) 天气关联分析：每种天气的情绪平均值
    // MVP：以任务当天的天气作为代理（任务生成时包含天气），用当天 mood 的平均来代表
    func weatherMoodAverages(entries: [MoodEntry], tasks: [Task]) -> [WeatherType: Double] {
        guard !entries.isEmpty else { return [:] }
        // 按天聚合 mood 平均
        var moodByDay: [Date: (sum: Int, count: Int)] = [:]
        for e in entries {
            let day = cal.startOfDay(for: e.date)
            var item = moodByDay[day] ?? (0,0)
            item.sum += e.value
            item.count += 1
            moodByDay[day] = item
        }
        let dayAvg: [Date: Double] = moodByDay.mapValues { Double($0.sum) / Double(max(1, $0.count)) }

        // 找到当天任务的主天气（取当天任务中出现最多的天气）
        var weatherByDay: [Date: WeatherType] = [:]
        let groupedTasks = Dictionary(grouping: tasks, by: { cal.startOfDay(for: $0.date) })
        for (day, ts) in groupedTasks {
            let counts = Dictionary(grouping: ts, by: { $0.weatherType }).mapValues { $0.count }
            if let dominant = counts.max(by: { $0.value < $1.value })?.key {
                weatherByDay[day] = dominant
            }
        }

        // 聚合到天气
        var acc: [WeatherType: (sum: Double, count: Int)] = [:]
        for (day, avg) in dayAvg {
            if let w = weatherByDay[day] {
                var item = acc[w] ?? (0, 0)
                item.sum += avg
                item.count += 1
                acc[w] = item
            }
        }
        return acc.mapValues { $0.count == 0 ? 0 : $0.sum / Double($0.count) }
    }

    // 3) 日照时长关联分析（占位：基于天气与时段的启发式描述）
    func daylightCorrelationText(entries: [MoodEntry]) -> String {
        // 占位：没有真实日照数据，给出启发式提示
        // 未来可接 WeatherKit 的太阳高度角 / 日照时长 API
        let slotAvg = timeSlotMoodAverages(entries: entries)
        guard !slotAvg.isEmpty else { return "暂无足够数据用于日照关联分析。" }
        let worst = slotAvg.min(by: { $0.value < $1.value })
        if let (slot, _) = worst {
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
}

