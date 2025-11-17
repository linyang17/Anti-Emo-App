import Foundation
import SwiftData

/// 情绪记录来源
public enum MoodSource: String, Codable, CaseIterable, Sendable {
    case appOpen = "app_open"
    case afterTask = "after_task"
}

@Model
final class MoodEntry: Identifiable, Codable {
	enum Source: String, Codable, CaseIterable, Sendable {
		case appOpen
		case afterTask
		case manual
	}

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

	private enum CodingKeys: String, CodingKey {
		case id
		case date
		case value
		case source
		case delta
		case relatedTaskCategory
		case relatedWeather
	}

	convenience init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let id = try container.decode(UUID.self, forKey: .id)
		let date = try container.decode(Date.self, forKey: .date)
		let value = try container.decode(Int.self, forKey: .value)
		let source = try container.decodeIfPresent(Source.self, forKey: .source) ?? MoodEntry.Source.appOpen
		let delta = try container.decodeIfPresent(Int.self, forKey: .delta)
		let relatedTaskCategory = try container.decodeIfPresent(TaskCategory.self, forKey: .relatedTaskCategory)
		let relatedWeather = try container.decodeIfPresent(WeatherType.self, forKey: .relatedWeather)
		self.init(
			id: id,
			date: date,
			value: value,
			source: source,
			delta: delta,
			relatedTaskCategory: relatedTaskCategory,
			relatedWeather: relatedWeather
		)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(date, forKey: .date)
		try container.encode(value, forKey: .value)
		try container.encode(source, forKey: .source)
		try container.encodeIfPresent(delta, forKey: .delta)
		try container.encodeIfPresent(relatedTaskCategory, forKey: .relatedTaskCategory)
		try container.encodeIfPresent(relatedWeather, forKey: .relatedWeather)
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
