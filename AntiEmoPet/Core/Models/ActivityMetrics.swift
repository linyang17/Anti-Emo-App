import Foundation

public enum TimeSlot: String, CaseIterable, Codable {
    case morning, afternoon, evening, night

    public static func slot(for date: Date, calendar: Calendar) -> TimeSlot {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }
}

public struct DailyActivityMetrics: Codable, Equatable {
    public let tasksCompletedByDay: [Date: Int]
    public let petInteractionsByDay: [Date: Int]
    public let timeslotCompletionsByDay: [Date: [TimeSlot: Int]]

    public init(
        tasksCompletedByDay: [Date: Int] = [:],
        petInteractionsByDay: [Date: Int] = [:],
        timeslotCompletionsByDay: [Date: [TimeSlot: Int]] = [:]
    ) {
        self.tasksCompletedByDay = tasksCompletedByDay
        self.petInteractionsByDay = petInteractionsByDay
        self.timeslotCompletionsByDay = timeslotCompletionsByDay
    }
}
