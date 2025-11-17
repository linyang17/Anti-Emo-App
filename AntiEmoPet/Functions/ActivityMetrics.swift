import Foundation

public enum TimeSlot: String, Codable, CaseIterable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    public static func from(date: Date, using calendar: Calendar) -> TimeSlot {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 6..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}

public struct DailyActivityMetrics: Codable, Sendable, Equatable {
    public var date: Date // startOfDay
    public var completedTaskCount: Int
    public var petInteractionCount: Int
    public var timeSlotTaskCounts: [TimeSlot: Int]

    public init(date: Date, completedTaskCount: Int = 0, petInteractionCount: Int = 0, timeSlotTaskCounts: [TimeSlot: Int] = [:]) {
        self.date = date
        self.completedTaskCount = completedTaskCount
        self.petInteractionCount = petInteractionCount
        self.timeSlotTaskCounts = timeSlotTaskCounts
    }
}
