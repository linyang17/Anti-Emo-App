import Foundation
import Combine
import CoreLocation

@MainActor
final class OnboardingViewModel: ObservableObject {
	enum GenderOption: String, CaseIterable, Identifiable {
		case male
		case female
		case other

		var id: String { rawValue }

		var displayName: String {
			switch self {
			case .male:
				return "Male"
			case .female:
				return "Female"
			case .other:
				return "Other"
			}
		}
	}
	
	@Published var nickname: String = ""
	@Published var region: String = ""
	@Published var notificationsOptIn: Bool = true
	@Published var enableLocationAndWeather: Bool = false
	@Published var hasLocationPermission: Bool = false
	@Published var hasWeatherPermission: Bool = false
	@Published var selectedGender: GenderOption?
	@Published var birthday: Date

	var canSubmit: Bool {
		!nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
		selectedGender != nil &&
		enableLocationAndWeather &&
		hasLocationPermission &&
		hasWeatherPermission &&
		birthday <= Date()
	}

	var statusText: String {
		if !enableLocationAndWeather {
			return "请开启定位与天气访问以继续"
		}
		if !hasLocationPermission {
			return "等待定位权限…"
		}
		if !hasWeatherPermission {
			return "等待天气权限…"
		}
		if region.isEmpty {
			return "正在解析城市…"
		}
		return "已准备好"
	}

	func updateLocationStatus(_ status: CLAuthorizationStatus) {
		hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
	}

	func setWeatherPermission(_ granted: Bool) {
		hasWeatherPermission = granted
	}

	init(defaultBirthday: Date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now) {
		self.birthday = defaultBirthday
	}
}

