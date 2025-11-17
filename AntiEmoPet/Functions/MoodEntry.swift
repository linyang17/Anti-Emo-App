import Foundation
import SwiftData

@Model
final class MoodEntry: Identifiable, Codable, Sendable {
	enum Source: String, Codable, CaseIterable, Sendable {
		case appOpen
		case afterTask
		case manual
	}

    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Int
	var source: Source
	var delta: Int?
	var relatedTaskCategory: TaskCategory?
	var relatedWeather: WeatherType?

	init(
		id: UUID = UUID(),
		date: Date = .now,
		value: Int,
		source: Source = .appOpen,
		delta: Int? = nil,
		relatedTaskCategory: TaskCategory? = nil,
		relatedWeather: WeatherType? = nil
	) {
        self.id = id
        self.date = date
        self.value = value
		self.source = source
		self.delta = delta
		self.relatedTaskCategory = relatedTaskCategory
		self.relatedWeather = relatedWeather
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
