import Foundation
import Combine
import CoreLocation
import GoogleSignIn
import AuthenticationServices
import UIKit
import OSLog


@MainActor
final class OnboardingViewModel: NSObject, ObservableObject {
	private let log = Logger(subsystem: "com.selena.AntiEmoPet", category: "Onboarding")
	
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

			var id: String { rawValue }

			var title: String {
					switch self {
					case .google: return "Google"
					case .icloud: return "iCloud"
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


	var canSubmit: Bool {
		accountEmail != "" &&
		!nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
		selectedGender != nil &&
		enableLocationAndWeather &&
		hasLocationPermission &&
		hasWeatherPermission &&
		birthday <= Date()
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
	
	// MARK: - Core Login
	func selectAccountProvider(_ provider: AccountProvider) {
		selectedAccountProvider = provider
		connectToProvider(provider)
	}

	private func connectToProvider(_ provider: AccountProvider) {
		switch provider {
		case .google: connectWithGoogle()
		case .icloud: connectWithICloud()
		}
	}

	private func connectWithGoogle() {
		guard let rootVC = UIApplication.shared.connectedScenes
			.compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
			.first else { return }

		GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, _ in
			guard let self,
				  let user = result?.user,
				  let email = user.profile?.email else { return }
			self.accountEmail = email
			self.selectedAccountProvider = .google
		}
	}
	
	
	private func connectWithICloud() {
		let request = ASAuthorizationAppleIDProvider().createRequest()
		request.requestedScopes = [.email]

		let controller = ASAuthorizationController(authorizationRequests: [request])
		controller.delegate = self
		controller.presentationContextProvider = self
		controller.performRequests()
	}
	

	init(defaultBirthday: Date = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .now) {
		self.birthday = defaultBirthday
		super.init()
	}
}

extension OnboardingViewModel: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
		// Use the key window as the presentation anchor
		if let window = UIApplication.shared.connectedScenes
			.compactMap({ $0 as? UIWindowScene })
			.flatMap({ $0.windows })
			.first(where: { $0.isKeyWindow }) {
			return window
		}
		return UIWindow()
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
		if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
			// New sign-in may include email (first time)
			if let email = appleIDCredential.email {
				self.accountEmail = email
			} else if let email = appleIDCredential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) {
				// Fallback: try to decode email from the identity token if available
				self.accountEmail = email
			}
			self.selectedAccountProvider = .icloud
		}
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		log.error("Apple sign in failed: \(error.localizedDescription)")
	}
}
