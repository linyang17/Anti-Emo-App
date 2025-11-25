import SwiftUI
import CoreLocation
import UIKit

@MainActor
struct OnboardingView: View {
	// MARK: - Dependencies
	@StateObject private var viewModel = OnboardingViewModel()
	@EnvironmentObject private var appModel: AppViewModel
	@ObservedObject private var locationService: LocationService
	@Environment(\.openURL) private var openURL

	// MARK: - View States
	@State private var step: Step = .intro
	@State private var isProcessingFinalStep = false
	@State private var showLocationDeniedAlert = false
	@State private var hasCompletedOnboarding = false

	// MARK: - Initialization
	init(locationService: LocationService? = nil) {
		_locationService = ObservedObject(wrappedValue: locationService ?? LocationService())
	}

	// MARK: - Body
	var body: some View {
		ZStack {
			GPUCachedBackground("bg-main")

			if step == .celebration {
				WelcomeView(onTap: handleAdvance)
					.id(step.rawValue)
					.transition(.opacity)
			} else {
				VStack {
					Spacer(minLength: 30)
					StepFactory(step: step, viewModel: viewModel, onAdvance: handleAdvance)
						.padding(.bottom, 24)
						.id(step.rawValue)
						.animation(.easeInOut(duration: 0.3), value: step)
					Spacer(minLength: 520)
				}

				VStack(spacing: 24) {
					Spacer(minLength: 300)
					OnboardingArrowButton(
						isEnabled: canAdvance,
						isLoading: isProcessingFinalStep,
						action: handleAdvance
					)
					FoxCharacterLayer()
				}
				.padding(.bottom, 50)
			}
		}
		.ignoresSafeArea(.keyboard, edges: .bottom)
		// MARK: - Alerts
		.alert("Can't access location and weather.", isPresented: $showLocationDeniedAlert) {
			Button("Go to settings") {
				if let url = URL(string: UIApplication.openSettingsURLString) {
					openURL(url)
				}
			}
		} message: {
			Text("You'll not be able to access personalised tasks without permission.")
		}
		// MARK: - Listeners
		.onChange(of: locationService.authorizationStatus, handleAuthorization)
		.onChange(of: locationService.lastKnownCity, updateCity)
		.onChange(of: step) { _, newStep in
			if newStep == .access {
				viewModel.updateLocationStatus(locationService.authorizationStatus)
			}
		}
		.task { await prepareInitialData() }
	}
}

// MARK: - Sub Logic
extension OnboardingView {
	enum Step: Int, CaseIterable {
		case intro, registration, name, gender, birthday, access, celebration
		var next: Step? { Step(rawValue: rawValue + 1) }
	}

	var canAdvance: Bool {
		switch step {
		case .intro: return true
		case .registration: return !viewModel.accountEmail.isEmpty
		case .name: return !viewModel.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		case .gender: return viewModel.selectedGender != nil
		case .birthday: return viewModel.birthday <= Date()
		case .access: return !isProcessingFinalStep
		case .celebration: return true
		}
	}

	// MARK: - Step Handling
	func handleAdvance() {
		guard canAdvance else { return }

		switch step {
		case .access:
			handleAccessFlow()
		case .celebration:
			finishOnboarding(shareLocation: true)
		default:
			if let next = step.next {
				withAnimation(.snappy(duration: 0.32)) {
					step = next
				}
			}
		}
	}

	// MARK: - Access & Authorization
	func handleAccessFlow() {
		switch locationService.authorizationStatus {
		case .authorizedAlways, .authorizedWhenInUse:
			viewModel.enableLocationAndWeather = true
			updateRegionAndCache()
			requestWeatherAndNotifications()

		case .denied, .restricted:
			viewModel.enableLocationAndWeather = false
			showLocationDeniedAlert = true

		case .notDetermined:
			isProcessingFinalStep = true
			locationService.requestLocAuthorization()
		@unknown default: break
		}
	}

	func handleAuthorization(_ old: CLAuthorizationStatus, _ new: CLAuthorizationStatus) {
		viewModel.updateLocationStatus(new)
		guard step == .access else { return }

		switch new {
		case .authorizedAlways, .authorizedWhenInUse:
			viewModel.enableLocationAndWeather = true
			isProcessingFinalStep = false
			updateRegionAndCache(delay: 1.0)
			requestWeatherAndNotifications()

		case .denied, .restricted:
			viewModel.enableLocationAndWeather = false
			isProcessingFinalStep = false
			showLocationDeniedAlert = true

		default:
			break
		}
	}

	// MARK: - Region & Caching
	func updateRegionAndCache(delay: Double = 0.5) {
		Task {
			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			if !locationService.lastKnownCity.isEmpty {
				let city = locationService.lastKnownCity
				viewModel.region = city
				await OnboardingCache.shared.setCity(city)
			}
		}
	}

	func updateCity(_ oldCity: String, _ newCity: String) {
		guard !newCity.isEmpty, viewModel.region.isEmpty else { return }
		viewModel.region = newCity
		Task { await OnboardingCache.shared.setCity(newCity) }
	}

	// MARK: - Weather & Notifications
	func requestWeatherAndNotifications() {
		guard !hasCompletedOnboarding else { return }

		Task {
			do {
				let granted = await appModel.requestWeatherAccess()
				await OnboardingCache.shared.setWeatherGranted(granted)
				viewModel.setWeatherPermission(granted)

				guard granted else {
					viewModel.enableLocationAndWeather = false
					showLocationDeniedAlert = true
					return
				}

				// Update region if missing
				if viewModel.region.isEmpty, !locationService.lastKnownCity.isEmpty {
					viewModel.region = locationService.lastKnownCity
				}

				// Request notifications if opted-in
				if viewModel.notificationsOptIn {
					appModel.requestNotifications()
				}

				withAnimation(.easeInOut) { step = .celebration }
			} catch {
				showLocationDeniedAlert = true
			}
		}
	}

	// MARK: - Initial Setup
	func prepareInitialData() async {
		viewModel.updateLocationStatus(locationService.authorizationStatus)

		async let cachedCityTask = OnboardingCache.shared.getCity()
		async let weatherGrantedTask = OnboardingCache.shared.getWeatherGranted()

		do {
			let cachedCity = try await cachedCityTask
			let weatherGranted = try await weatherGrantedTask

			if let city = cachedCity, !city.isEmpty {
				viewModel.region = city
			} else if !locationService.lastKnownCity.isEmpty {
				let city = locationService.lastKnownCity
				viewModel.region = city
				await OnboardingCache.shared.setCity(city)
			}

			if let granted = weatherGranted {
				viewModel.setWeatherPermission(granted)
			} else {
				viewModel.setWeatherPermission(locationService.weatherPermissionGranted)
			}
		} catch {
			// Fallback: gracefully recover
			if !locationService.lastKnownCity.isEmpty {
				viewModel.region = locationService.lastKnownCity
			}
			viewModel.setWeatherPermission(locationService.weatherPermissionGranted)
		}
	}

	// MARK: - Completion
	func finishOnboarding(shareLocation: Bool) {
		guard !hasCompletedOnboarding else { return }

		isProcessingFinalStep = false

		let genderRaw = viewModel.selectedGender?.rawValue ?? GenderIdentity.unspecified.rawValue
		let region = viewModel.region.isEmpty ? locationService.lastKnownCity : viewModel.region

		viewModel.enableLocationAndWeather = shareLocation

		appModel.updateProfile(
			nickname: viewModel.nickname,
			region: region,
			shareLocation: shareLocation,
			gender: genderRaw,
			birthday: viewModel.birthday,
			accountEmail: viewModel.accountEmail,
			Onboard: true
		)

		hasCompletedOnboarding = true
	}
}
