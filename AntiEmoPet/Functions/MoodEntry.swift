import Foundation
import SwiftData

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
	var source: Source = MoodEntry.Source.appOpen
	var delta: Int? = nil
	var relatedTaskCategory: TaskCategory? = nil
	var relatedWeather: WeatherType? = nil

    init(id: UUID = UUID(), date: Date = .now, value: Int) {
        self.id = id
        self.date = date
        self.value = value
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
