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
	
	enum AccountProvider: String, CaseIterable, Identifiable {
			case google
			case icloud
			case email

			var id: String { rawValue }

			var title: String {
					switch self {
					case .google: return "Google"
					case .icloud: return "iCloud"
					case .email: return "Email"
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
	@Published var selectedAccountProvider: AccountProvider?
	@Published var accountEmail: String = ""
	@Published var emailInput: String = ""
	@Published var emailConfirmationSent: Bool = false
	@Published var isAccountVerified: Bool = false


	var canSubmit: Bool {
			!nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
			selectedGender != nil &&
			enableLocationAndWeather &&
			hasLocationPermission &&
			hasWeatherPermission &&
			birthday <= Date() &&
			hasVerifiedAccount
	}
	
	var hasVerifiedAccount: Bool {
			guard selectedAccountProvider != nil else { return false }
			return isAccountVerified && !accountEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var isEmailInputValid: Bool {
			let trimmed = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.contains("@") && trimmed.contains(".")
	}



	var statusText: String {
		if !enableLocationAndWeather {
			return "Please allow location access to continue."
		}
		if !hasLocationPermission {
			return "Awaiting permission..."
		}
		if !hasWeatherPermission {
			return "Awaiting permission..."
		}
		if region.isEmpty {
			return "Locating"
		}
		return "Ready"
	}

	func updateLocationStatus(_ status: CLAuthorizationStatus) {
		hasLocationPermission = status == .authorizedWhenInUse || status == .authorizedAlways
	}

	func setWeatherPermission(_ granted: Bool) {
		hasWeatherPermission = granted
	}
	
	func selectAccountProvider(_ provider: AccountProvider) {
			selectedAccountProvider = provider
			switch provider {
			case .google:
					accountEmail = makePlaceholderEmail(domain: "gmail.com")
					emailInput = ""
					isAccountVerified = true
					emailConfirmationSent = false
			case .icloud:
					accountEmail = makePlaceholderEmail(domain: "icloud.com")
					emailInput = ""
					isAccountVerified = true
					emailConfirmationSent = false
			case .email:
					if !accountEmail.isEmpty {
							emailInput = accountEmail
					}
					accountEmail = ""
					isAccountVerified = false
					emailConfirmationSent = false
			}
	}

	func sendEmailConfirmation() {
			guard selectedAccountProvider == .email, isEmailInputValid else { return }
			emailConfirmationSent = true
			isAccountVerified = false
	}

	func confirmEmailVerification() {
			guard selectedAccountProvider == .email, emailConfirmationSent, isEmailInputValid else { return }
			accountEmail = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
			isAccountVerified = true
	}

	private func makePlaceholderEmail(domain: String) -> String {
			let base = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
			let allowed = base.lowercased().map { character -> Character? in
					if character.isLetter || character.isNumber { return character }
					if character == " " { return "." }
					return nil
			}.compactMap { $0 }
			let username = allowed.isEmpty ? "lumio.friend" : String(allowed)
			return "\(username)@\(domain)"
	}


	init(defaultBirthday: Date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now) {
		self.birthday = defaultBirthday
	}
}

