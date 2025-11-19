import Foundation
import SwiftData


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


@Model
final class SunTimesRecord: Identifiable {
	@Attribute(.unique) var id: UUID
	var day: Date
	var sunrise: Date
	var sunset: Date
	var updatedAt: Date

	init(
		id: UUID = UUID(),
		day: Date,
		sunrise: Date,
		sunset: Date,
		updatedAt: Date = .now
	) {
		self.id = id
		self.day = day
		self.sunrise = sunrise
		self.sunset = sunset
		self.updatedAt = updatedAt
	}
}

