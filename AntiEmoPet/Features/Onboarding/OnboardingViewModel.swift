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
		guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

		// 用户第一次授权时才会有 email
		if let email = appleIDCredential.email {
			self.accountEmail = email
			log.info("📧 Received Apple ID email: \(email)")
		} else {
			// 第二次及之后授权不会再返回 email
			log.info("ℹ️ Apple sign-in: email not returned (already authorized before)")
		}

		// 保存用户唯一标识符，用于后续登录
		let userID = appleIDCredential.user
		log.info("🆔 Apple ID user ID: \(userID)")

		// 如果你想进一步尝试从 identityToken 解码邮箱，可以安全解析 JWT：
		if let identityToken = appleIDCredential.identityToken,
		   let jwtString = String(data: identityToken, encoding: .utf8) {
			if let decodedEmail = decodeEmailFromIdentityToken(jwtString) {
				self.accountEmail = decodedEmail
				log.info("📨 Extracted email from JWT: \(decodedEmail)")
			}
		}

		self.selectedAccountProvider = .icloud
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		log.error("Apple sign in failed: \(error.localizedDescription)")
	}
	
	private func decodeEmailFromIdentityToken(_ jwt: String) -> String? {
		// JWT 分成三段：header.payload.signature
		let segments = jwt.split(separator: ".")
		guard segments.count > 1 else { return nil }

		let payloadSegment = segments[1]
		var base64 = String(payloadSegment)
		// 补齐 base64 padding
		let requiredLength = 4 * ((base64.count + 3) / 4)
		base64 = base64.padding(toLength: requiredLength, withPad: "=", startingAt: 0)
		base64 = base64.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")

		guard let data = Data(base64Encoded: base64),
			  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
			return nil
		}

		return json["email"] as? String
	}
	
}
