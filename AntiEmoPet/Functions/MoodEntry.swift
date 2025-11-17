import Foundation
import SwiftData

@Model
final class MoodEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Int

    init(id: UUID = UUID(), date: Date = .now, value: Int) {
        self.id = id
        self.date = date
        self.value = value
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
