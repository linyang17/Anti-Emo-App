import SwiftUI
import SwiftData

struct ContentView: View {
	@EnvironmentObject var appModel: AppViewModel
	@State private var showWelcome = false

	var body: some View {
		Group {
			if appModel.isLoading {
				ProgressView("Loading…")
			} else {
				MainTabView()
			}
		}
		.task {
			if !appModel.isLoading {
				evaluateWelcomeDisplay()
			}
		}
		.fullScreenCover(isPresented: $showWelcome) {
			WelcomeView {
				showWelcome = false
			}
		}
	}

	private func evaluateWelcomeDisplay() {
		guard let onboarded = appModel.userStats?.Onboard else { return }
		showWelcome = onboarded
	}
}

struct MainTabView: View {
	@EnvironmentObject private var appModel: AppViewModel

	private var onboardingBinding: Binding<Bool> {
		Binding(
			get: { appModel.showOnboarding },
			set: { appModel.showOnboarding = $0 }
		)
	}

	private var sleepAlertBinding: Binding<Bool> {
		Binding(
			get: { appModel.showSleepReminder && !appModel.showOnboarding },
			set: { newValue in
				if !newValue {
					appModel.dismissSleepReminder()
				}
			}
		)
	}

	var body: some View {
		NavigationStack {
			PetView()
		}
		.fullScreenCover(isPresented: onboardingBinding) {
			OnboardingView(locationService: appModel.locationService)
		}
		.interactiveDismissDisabled(true)
		.alert("Time for bed...",
			   isPresented: sleepAlertBinding) {
			Button("Okay", role: .cancel) {
				appModel.dismissSleepReminder()
			}
		} message: {
			Text("It seems quite late for you, Lumio is also going to take some rest - we shall catch up tomorrow!")
		}
	}
}
