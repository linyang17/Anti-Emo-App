import Foundation
import SwiftData

/// 情绪记录来源
public enum MoodSource: String, Codable, CaseIterable, Sendable {
    case appOpen = "app_open"
    case afterTask = "after_task"
}

@Model
final class MoodEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Int
    var source: String = MoodSource.appOpen.rawValue  // MoodSource.rawValue，使用 String 以兼容 SwiftData，默认值用于数据迁移
    var delta: Int?  // 完成任务后的情绪变化
    var relatedTaskCategory: String?  // TaskCategory.rawValue
    var relatedWeather: String?  // WeatherType.rawValue

    init(
        id: UUID = UUID(),
        date: Date = .now,
        value: Int,
        source: MoodSource = .appOpen,
        delta: Int? = nil,
        relatedTaskCategory: TaskCategory? = nil,
        relatedWeather: WeatherType? = nil
    ) {
        self.id = id
        self.date = date
        self.value = value
        self.source = source.rawValue
        self.delta = delta
        self.relatedTaskCategory = relatedTaskCategory?.rawValue
        self.relatedWeather = relatedWeather?.rawValue
    }
    
    // MARK: - Computed Properties for Type Safety
    var moodSource: MoodSource {
        get { MoodSource(rawValue: source) ?? .appOpen }
        set { source = newValue.rawValue }
    }
    
    var category: TaskCategory? {
        get {
            guard let raw = relatedTaskCategory else { return nil }
            return TaskCategory(rawValue: raw)
        }
        set { relatedTaskCategory = newValue?.rawValue }
    }
    
    var weather: WeatherType? {
        get {
            guard let raw = relatedWeather else { return nil }
            return WeatherType(rawValue: raw)
        }
        set { relatedWeather = newValue?.rawValue }
    }
}

public enum MoodLevel: String, Codable, CaseIterable, Sendable {
	case low
	case neutral
	case high
	
	public static func from(_ value: Double) -> MoodLevel {
		switch value {
		case ..<35:
			return .low
		case 35..<70:
			return .neutral
		default:
			return .high
		}
	}

	/// 如果 lastMood 是 Int，也可以直接支持
	public static func from(_ value: Int) -> MoodLevel {
		return MoodLevel.from(Double(value))
	}
}
