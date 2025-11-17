import Foundation
import SwiftData

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

