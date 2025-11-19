import Foundation

struct UserTimeslotSummary: Codable, Sendable {
    // User Info
    let userId: String
    let countryRegion: String
    
    // Time Info
    let date: Date
    let dayLength: TimeInterval // seconds
    let timeSlot: String // "morning", etc.
    
    // Weather
    let timeslotWeather: String? // WeatherType.rawValue
    
    // Metrics
    let countMood: Int
    let avgMood: Double
    let totalEnergyGain: Int
    let moodDeltaAfterTasks: Double // Avg delta
    
    // Task Summary: { "outdoor": [completed, total] }
    let tasksSummary: [String: [Int]]
}

@MainActor
final class DataAggregationService {
    private let calendar = TimeZoneManager.shared.calendar
    
    func aggregate(
        userId: String,
        region: String,
        date: Date,
        moodEntries: [MoodEntry],
        tasks: [UserTask],
        sunEvents: [Date: SunTimes]
    ) -> [UserTimeslotSummary] {
        let startOfDay = calendar.startOfDay(for: date)
        
        // Filter data for the specific date
        let dailyMoods = moodEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let dailyTasks = tasks.filter { calendar.isDate($0.date, inSameDayAs: date) }
        
        // Calculate day length
        var dayLength: TimeInterval = 0
        if let sunTime = sunEvents[startOfDay] {
            dayLength = sunTime.sunset.timeIntervalSince(sunTime.sunrise)
        }
        
        var summaries: [UserTimeslotSummary] = []
        
        for slot in TimeSlot.allCases {
            // Filter by slot
            let slotMoods = dailyMoods.filter { TimeSlot.from(date: $0.date, using: calendar) == slot }
            let slotTasks = dailyTasks.filter {
                // Assuming task date is creation time, use that for slot grouping
                // Or use completedAt if status is completed?
                // For aggregation, usually we look at when the activity happened.
                // Tasks have `date` (creation) and `completedAt`.
                // PRD says "tasks completed".
                guard let completedAt = $0.completedAt else { return false }
                return TimeSlot.from(date: completedAt, using: calendar) == slot
            }
            
            // Weather for slot (dominant from tasks or first mood entry)
            let weather = determineWeather(for: slotMoods, tasks: slotTasks)
            
            // Mood metrics
            let countMood = slotMoods.count
            let avgMood = countMood > 0 ? Double(slotMoods.reduce(0) { $0 + $1.value }) / Double(countMood) : 0
            
            // Energy Gain
            let energyGain = slotTasks.reduce(0) { $0 + $1.energyReward }
            
            // Mood Delta
            let deltaMoods = slotMoods.compactMap { $0.delta }
            let avgDelta = !deltaMoods.isEmpty ? Double(deltaMoods.reduce(0, +)) / Double(deltaMoods.count) : 0
            
            // Task Summary
            var taskSummaryMap: [String: [Int]] = [:]
            let tasksByCat = Dictionary(grouping: slotTasks, by: { $0.category })
            // Need "total" tasks... but `slotTasks` are only completed ones if we filtered by `completedAt`.
            // If we want "generated" tasks for the slot, we need to look at creation date.
            // Let's stick to completed for now or try to fetch created tasks for this slot?
            // The prompt says "tasks_completed_total_by_type" e.g. [completed, total].
            // We need tasks created in this slot too.
            let tasksCreatedInSlot = dailyTasks.filter {
                TimeSlot.from(date: $0.date, using: calendar) == slot
            }
            let allCategories = Set(tasksCreatedInSlot.map { $0.category }.compactMap { $0 }).union(tasksByCat.keys)
            
            for cat in allCategories {
                let total = tasksCreatedInSlot.filter { $0.category == cat }.count
                let completed = tasksByCat[cat]?.count ?? 0
                taskSummaryMap[cat.rawValue] = [completed, total]
            }
            
            let summary = UserTimeslotSummary(
                userId: userId,
                countryRegion: region,
                date: startOfDay,
                dayLength: dayLength,
                timeSlot: slot.rawValue,
                timeslotWeather: weather?.rawValue,
                countMood: countMood,
                avgMood: avgMood,
                totalEnergyGain: energyGain,
                moodDeltaAfterTasks: avgDelta,
                tasksSummary: taskSummaryMap
            )
            
            summaries.append(summary)
        }
        
        return summaries
    }
    
    private func determineWeather(for moods: [MoodEntry], tasks: [UserTask]) -> WeatherType? {
        // Prioritize mood entry related weather
        if let firstWeather = moods.compactMap({ $0.weather }).first {
            return firstWeather
        }
        // Fallback to task weather
        if let firstTask = tasks.first {
            return firstTask.weatherType
        }
        return nil
    }
}

