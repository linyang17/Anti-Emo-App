import Foundation
import Combine

enum DayPeriod: String, CaseIterable, Identifiable, Sendable {
    case daylight
    case night

    var id: String { rawValue }

    var dayPeriodTitle: String {
        switch self {
        case .daylight: return "Daylight"
        case .night: return "Dark"
        }
    }
}

enum TrendDirection: String, Codable, Sendable {
		case up = "⬆"
		case down = "↓"
		case flat = ""
}

@MainActor
final class AnalysisViewModel: ObservableObject {
    private let cal: Calendar = TimeZoneManager.shared.calendar

    // MARK: - Published Outputs (optional for UI binding)
    @Published var timeSlotAverages: [TimeSlot: Double] = [:]
    @Published var weatherAverages: [WeatherType: Double] = [:]
    @Published var daylightHint: String = ""
    @Published var dayPeriodAverages: [DayPeriod: Double] = [:]
    @Published var heatmapData: [TimeSlot: [Int: Double]] = [:]
    @Published var daylightLengthData: [Int: Double] = [:]

    // MARK: - Unified Wrapper Function
    func rhythmAnalysis(for entries: [MoodEntry], sunEvents: [Date: SunTimes]) -> (
        timeSlot: [TimeSlot: Double],
        weather: [WeatherType: Double],
        daylight: String,
        dayPeriod: [DayPeriod: Double]
    ) {
        let slot = timeSlotMoodAverages(entries: entries)
        let weather = weatherMoodAverages(entries: entries)
        let daylightBuckets = daylightMoodAverages(entries: entries, sunEvents: sunEvents)
        let text = daylightCorrelationText(slotAverages: slot)
        let heatmap = timeSlotAndWeekdayMoodAverages(entries: entries)
        let daylightLen = daylightLengthMoodAverages(entries: entries, sunEvents: sunEvents)

        timeSlotAverages = slot
        weatherAverages = weather
        dayPeriodAverages = daylightBuckets
        daylightHint = text
        heatmapData = heatmap
        daylightLengthData = daylightLen

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

	// 2) 情绪与天气关联度分析：
    private func weatherMoodAverages(entries: [MoodEntry]) -> [WeatherType: Double] {
        guard !entries.isEmpty else { return [:] }

        var accumulator: [WeatherType: (sum: Int, count: Int)] = [:]
        
        for entry in entries {
            guard let weather = entry.weather else { continue }
            var bucket = accumulator[weather] ?? (0, 0)
            bucket.sum += entry.value
            bucket.count += 1
            accumulator[weather] = bucket
        }

        return accumulator.reduce(into: [:]) { result, element in
            let (weather, bucket) = element
            guard bucket.count > 0 else { return }
            result[weather] = Double(bucket.sum) / Double(bucket.count)
        }
    }

	// 3) TODO: 情绪与日照时长关联度分析：
    private func daylightCorrelationText(slotAverages: [TimeSlot: Double]) -> String {
        guard !slotAverages.isEmpty else { return "Not enough data for analysis. Try to enter some moods and complete more tasks!" }

		if let (slot, _) = slotAverages.min(by: { $0.value < $1.value }) {
			switch slot {
			case .morning:
				return "Hmm... mornings seem a bit gloomy. Maybe a warm drink and a bit of sunshine will cheer you up!"
			case .afternoon:
				return "Afternoons seem a little slow. How about a short walk outside or a quick stretch?"
			case .evening:
				return "Evenings feel a bit low. Lumio will find you something cozy to do before the stars come out."
			case .night:
				return "Nights can feel heavy sometimes. Lumio reckon it’s time to take some good rest and dream under the moon."
			}
		}

		return "Your mood feel balanced across the day — no big sunshine swings this time!"

    }

    // 日间平均情绪
    private func daylightMoodAverages(entries: [MoodEntry], sunEvents: [Date: SunTimes]) -> [DayPeriod: Double] {
        guard !entries.isEmpty else { return [:] }

        var accumulator: [DayPeriod: (sum: Int, count: Int)] = [:]
        for entry in entries {
            let day = cal.startOfDay(for: entry.date)
            let period: DayPeriod
            if let sun = sunEvents[day] {
                if entry.date >= sun.sunrise && entry.date < sun.sunset {
                    period = .daylight
                } else {
                    period = .night
                }
            } else {
                let slot = TimeSlot.from(date: entry.date, using: cal)
                period = switch slot {
                case .morning, .afternoon: .daylight
                case .evening, .night: .night
                }
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

    // 4.2 Heatmap Data: TimeSlot + Weekday -> Mood
    func timeSlotAndWeekdayMoodAverages(entries: [MoodEntry]) -> [TimeSlot: [Int: Double]] {
        guard !entries.isEmpty else { return [:] }
        var accumulator: [TimeSlot: [Int: (sum: Int, count: Int)]] = [:]

        for entry in entries {
            let slot = TimeSlot.from(date: entry.date, using: cal)
            let weekday = cal.component(.weekday, from: entry.date) // 1=Sun, ... 7=Sat
            
            var slotMap = accumulator[slot] ?? [:]
            var bucket = slotMap[weekday] ?? (0, 0)
            bucket.sum += entry.value
            bucket.count += 1
            accumulator[slot] = bucket
        }

        var result: [TimeSlot: [Int: Double]] = [:]
        for (slot, slotMap) in accumulator {
            var weekdayMap: [Int: Double] = [:]
            for (weekday, bucket) in slotMap {
                weekdayMap[weekday] = Double(bucket.sum) / Double(bucket.count)
            }
            result[slot] = weekdayMap
        }
        return result
    }

    // 4.5 Daylight Duration Line Chart Data
    func daylightLengthMoodAverages(entries: [MoodEntry], sunEvents: [Date: SunTimes]) -> [Int: Double] {
        guard !entries.isEmpty else { return [:] }
        // Group by day -> calculate avg mood for day -> correlate with daylight duration of that day
        
        let dayGroups = Dictionary(grouping: entries) { cal.startOfDay(for: $0.date) }
        var durationAccumulator: [Int: (sum: Double, count: Int)] = [:] // Duration (hours) -> sum of daily avg mood

        for (day, dailyEntries) in dayGroups {
            guard let sun = sunEvents[day] else { continue }
            let duration = sun.sunset.timeIntervalSince(sun.sunrise)
            let hours = Int(round(duration / 3600.0))
            guard hours > 0 else { continue }

            let dailySum = dailyEntries.reduce(0) { $0 + $1.value }
            let dailyAvg = Double(dailySum) / Double(dailyEntries.count)

            var bucket = durationAccumulator[hours] ?? (0.0, 0)
            bucket.sum += dailyAvg
            bucket.count += 1
            durationAccumulator[hours] = bucket
        }

        var result: [Int: Double] = [:]
        for (hours, bucket) in durationAccumulator {
            result[hours] = bucket.sum / Double(bucket.count)
        }
        return result
    }
}
