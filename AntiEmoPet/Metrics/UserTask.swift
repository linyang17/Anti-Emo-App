import Foundation
import SwiftData


enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case outdoor
    case indoorDigital
    case indoorActivity
	case physical
    case socials
    case petCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outdoor: return "Outdoor Activities"
        case .indoorDigital: return "Digital"
        case .indoorActivity: return "Indoor Activities"
        case .socials: return "Social Interactions"
        case .petCare: return "Pet Care"
		case .physical: return "Physical Exercises"
		}
    }
	
	/// Buffer时间(秒) - 开始任务后必须等待的时间
	var bufferDuration: TimeInterval {
		switch self {
		case .outdoor: return 5 * 60       // 5分钟
		case .indoorDigital: return 3 * 60 // 3分钟
		case .indoorActivity: return 3 * 60 // 3分钟
		case .physical: return 2 * 60      // 2分钟
		case .socials: return 3 * 60       // 3分钟
		case .petCare: return 15           // 15秒
		}
	}
	
	/// 完成任务获得的能量奖励
	var energyReward: Int {
		switch self {
		case .outdoor: return 15
		case .indoorDigital: return 5
		case .indoorActivity: return 10
		case .physical: return 15
		case .socials: return 10
		case .petCare: return 5
		}
	}
}

enum TaskStatus: String, Codable, CaseIterable, Sendable {
	case pending
	case started
	case ready
	case completed

	var isCompletable: Bool {
		self == .ready || self == .pending
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



@Model
final class UserTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var weatherType: WeatherType
    var category: TaskCategory
    var energyReward: Int = 0
    var date: Date
    var status: TaskStatus
    var startedAt: Date?  // 任务开始时间
    var canCompleteAfter: Date?  // 可以完成的最早时间（buffer 时间后）
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        weatherType: WeatherType,
        category: TaskCategory,
        energyReward: Int,
        date: Date,
        status: TaskStatus = .pending,
        startedAt: Date? = nil,
        canCompleteAfter: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.weatherType = weatherType
        self.category = category
        self.energyReward = energyReward
        self.date = date
        self.status = status
        self.startedAt = startedAt
        self.canCompleteAfter = canCompleteAfter
        self.completedAt = completedAt
    }
}
