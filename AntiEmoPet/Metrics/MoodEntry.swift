import Foundation
import SwiftData


@Model
final class MoodEntry: Identifiable, Codable {
	
	enum MoodSource: String, Codable, CaseIterable, Sendable {
		case appOpen
		case afterTask
		case manual
	}

    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Int
        var source: String = MoodSource.manual.rawValue   // default to manual
    var delta: Int?  // 完成任务后的情绪变化
    var relatedTaskCategory: String?  // TaskCategory.rawValue
    var relatedWeather: String?  // WeatherType.rawValue
    var relatedDayLength: Int? // minutes from sunrise to sunset

    init(
        id: UUID = UUID(),
        date: Date = .now,
        value: Int,
                source: MoodSource = .manual,
        delta: Int? = nil,
        relatedTaskCategory: TaskCategory? = nil,
        relatedWeather: WeatherType? = nil,
        relatedDayLength: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.value = value
        self.source = source.rawValue
        self.delta = delta
        self.relatedTaskCategory = relatedTaskCategory?.rawValue
        self.relatedWeather = relatedWeather?.rawValue
        self.relatedDayLength = relatedDayLength
    }
    
    // MARK: - Computed Properties for Type Safety
    var moodSource: MoodSource {
        get { MoodSource(rawValue: source) ?? .manual }
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
                case relatedDayLength
        }

	convenience init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let id = try container.decode(UUID.self, forKey: .id)
		let date = try container.decode(Date.self, forKey: .date)
                let value = try container.decode(Int.self, forKey: .value)
                let source = try container.decode(MoodSource.self, forKey: .source)
                let delta = try container.decodeIfPresent(Int.self, forKey: .delta)
                let relatedTaskCategory = try container.decodeIfPresent(TaskCategory.self, forKey: .relatedTaskCategory)
                let relatedWeather = try container.decodeIfPresent(WeatherType.self, forKey: .relatedWeather)
                let relatedDayLength = try container.decodeIfPresent(Int.self, forKey: .relatedDayLength)
                self.init(
                        id: id,
                        date: date,
                        value: value,
                        source: source,
                        delta: delta,
                        relatedTaskCategory: relatedTaskCategory,
                        relatedWeather: relatedWeather,
                        relatedDayLength: relatedDayLength
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
                try container.encodeIfPresent(relatedDayLength, forKey: .relatedDayLength)
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
