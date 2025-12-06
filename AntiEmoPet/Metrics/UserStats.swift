import Foundation
import SwiftData

enum GenderIdentity: String {
	case male
	case female
	case other
	case unspecified

	var displayName: String {
		switch self {
		case .male:
			return "Male"
		case .female:
			return "Female"
		case .other:
			return "Other"
		case .unspecified:
			return "Unspecified"
		}
	}
}

@Model
final class UserStats: Identifiable {
	@Attribute(.unique) var id: UUID = UUID()
	
	var totalEnergy: Int = 0
	var totalDays: Int = 0
	var lastActiveDate: Date = Date()
	var completedTasksCount: Int = 0
	var nickname: String = ""
	var region: String = ""
	var notificationsEnabled: Bool = false
	var shareLocationAndWeather: Bool = false
	var gender: String = GenderIdentity.unspecified.rawValue
	var birthday: Date?
	var accountEmail: String = ""
	var isOnboard: Bool = false
	var regionLocality: String = ""
	var regionAdministrativeArea: String = ""
	var regionCountry: String = ""
	var randomizeTaskTime: Bool = false
	var hasShownOnboardingCelebration: Bool = false

	init() {}
}
