import SwiftUI
import CoreLocation
import UIKit

@MainActor
struct OnboardingView: View {
	@StateObject private var viewModel = OnboardingViewModel()
	@EnvironmentObject private var appModel: AppViewModel
	@ObservedObject private var locationService: LocationService
	@Environment(\.openURL) private var openURL

	@State private var step: Step = .intro
	@State private var isProcessingFinalStep = false
	@State private var showLocationDeniedAlert = false
	@State private var hasCompletedOnboarding = false
	@State private var dragOffset: CGFloat = .zero
	@State private var hasTriggeredHapticPreview = false

	init(locationService: LocationService? = nil) {
		_locationService = ObservedObject(wrappedValue: locationService ?? LocationService())
	}

        var body: some View {
                ZStack {
                        GPUCachedBackground("bg-main")

                        if step == .celebration {
                                WelcomeView(onTap: handleAdvance)
                                        .id(step.rawValue)
                                        .transition(.opacity)
                        } else {
                                VStack {
                                        Spacer(minLength: 50)

                                        StepFactory(
                                                step: step,
                                                viewModel: viewModel,
                                                onAdvance: handleAdvance
                                        )
                                        .id(step.rawValue)
                                        .animation(.easeInOut(duration: 0.3), value: step)

                                        Spacer(minLength: 520)
                                }

                                VStack (spacing: 24) {
                                        Spacer(minLength: 300)

                                        OnboardingArrowButton(
                                                isEnabled: canAdvance,
                                                isLoading: isProcessingFinalStep,
                                                action: handleAdvance
                                        )
                                        .gesture(backSwipeGesture)

                                        FoxCharacterLayer()
                                }
                                .padding(.bottom, 50)
                        }
                }
                .background(NavigationGestureDisabler(isDisabled: true))
		.alert("Can't access location and weather.", isPresented: $showLocationDeniedAlert) {
			Button("Go to settings") {
				if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
			}
		} message: {
			Text("You'll not be able to access personalised tasks without permission.")
		}
		.task { await prepareInitialData() }
		.onChange(of: locationService.authorizationStatus, handleAuthorization)
		.onChange(of: step) { _, newStep in
			if newStep == .access {
				viewModel.updateLocationStatus(locationService.authorizationStatus)
			}
		}
	}
}


extension OnboardingView {
	
	enum Step: Int, CaseIterable {
		case intro, registration, name, gender, birthday, access, celebration
		var next: Step? { Step(rawValue: rawValue + 1) }
		var previous: Step? { Step(rawValue: rawValue - 1) }
	}
	
	var canAdvance: Bool {
		switch step {
		case .intro: return true
		case .registration: return !viewModel.accountEmail.isEmpty
		case .name: return !viewModel.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		case .gender: return viewModel.selectedGender != nil
		case .birthday: return viewModel.birthday <= Date()
		case .access: return !isProcessingFinalStep
		case .celebration: return false
		}
	}

	func handleAdvance() {
		guard canAdvance else { return }
		switch step {
		case .access: handleAccessFlow()
			
		case .celebration:
			finishOnboarding(shareLocation: true)
			
		default:
			if let next = step.next {
				withAnimation(.snappy(duration: 0.32)) { step = next }
				if next == .name {
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {}
				}
			}
		}
	}

	func handleAccessFlow() {
		switch locationService.authorizationStatus {
		case .authorizedAlways, .authorizedWhenInUse:
			viewModel.enableLocationAndWeather = true
			locationService.requestLocationOnce()
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
			isProcessingFinalStep = false
		case .denied, .restricted:
			viewModel.enableLocationAndWeather = false
			isProcessingFinalStep = false
			showLocationDeniedAlert = true
		default: break
		}
	}

	func requestWeatherAndNotifications() {
		guard !hasCompletedOnboarding else { return }
		Task.detached(priority: .background) {
			let granted = await appModel.requestWeatherAccess()
			await OnboardingCache.shared.setWeatherGranted(granted)
			await MainActor.run {
				viewModel.setWeatherPermission(granted)
				if granted {
					if viewModel.notificationsOptIn { appModel.requestNotifications() }
					withAnimation(.easeInOut) { step = .celebration }
				} else {
					viewModel.enableLocationAndWeather = false
					showLocationDeniedAlert = true
				}
			}
		}
	}

	func prepareInitialData() async {
		viewModel.updateLocationStatus(locationService.authorizationStatus)
		if let cachedCity = await OnboardingCache.shared.getCity() {
			viewModel.region = cachedCity
		} else if !locationService.lastKnownCity.isEmpty {
			viewModel.region = locationService.lastKnownCity
			await OnboardingCache.shared.setCity(locationService.lastKnownCity)
		}
		if let granted = await OnboardingCache.shared.getWeatherGranted() {
			viewModel.setWeatherPermission(granted)
		} else {
			viewModel.setWeatherPermission(locationService.weatherPermissionGranted)
		}
	}

	func finishOnboarding(shareLocation: Bool) {
		guard !hasCompletedOnboarding else { return }
		isProcessingFinalStep = false
		
		let trimmedName = viewModel.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
		let genderRaw = viewModel.selectedGender?.rawValue ?? GenderIdentity.unspecified.rawValue

		viewModel.enableLocationAndWeather = shareLocation

		appModel.updateProfile(
			nickname: trimmedName,
			region: viewModel.region,
			shareLocation: shareLocation,
			gender: genderRaw,
			birthday: viewModel.birthday,
			accountEmail: viewModel.accountEmail,
			Onboard: true
		)
		hasCompletedOnboarding = true
	}

	var backSwipeGesture: some Gesture {
		DragGesture(minimumDistance: 20)
			.onChanged { v in
				guard v.translation.width > 0 else {
					dragOffset = 0; hasTriggeredHapticPreview = false; return
				}
				dragOffset = min(v.translation.width, 160)
				if !hasTriggeredHapticPreview, dragOffset > 40, step.previous != nil {
					UIImpactFeedbackGenerator(style: .soft).impactOccurred()
					hasTriggeredHapticPreview = true
				}
			}
			.onEnded { v in
				defer {
					withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { dragOffset = 0 }
					hasTriggeredHapticPreview = false
				}
				if v.translation.width > 90 { handleRetreat() }
			}
	}

	func handleRetreat() {
		guard let previous = step.previous else { return }
		UIImpactFeedbackGenerator(style: .soft).impactOccurred()
		withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { step = previous }
		isProcessingFinalStep = false
	}
}
