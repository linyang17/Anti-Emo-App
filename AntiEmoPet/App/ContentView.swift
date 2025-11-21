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
		.onChange(of: appModel.isLoading) { _, isLoading in
			if !isLoading {
				checkShowWelcome()
			}
		}
		.onAppear {
			if !appModel.isLoading {
				checkShowWelcome()
			}
		}
		.fullScreenCover(isPresented: $showWelcome) {
			WelcomeView {
				showWelcome = false
			}
		}
	}

	private func checkShowWelcome() {
		if appModel.userStats?.Onboard == true {
			showWelcome = true
		}
	}
}

struct MainTabView: View {
	@EnvironmentObject private var appModel: AppViewModel

	var body: some View {
		NavigationStack { PetView() }
			.fullScreenCover(isPresented: Binding(
				get: { appModel.showOnboarding },
				set: { appModel.showOnboarding = $0 }
			)) {
				OnboardingView(locationService: appModel.locationService)
			}
			.interactiveDismissDisabled(true)
			.alert(
				"Time for bed...",
				isPresented: Binding(
					get: { appModel.showSleepReminder && !appModel.showOnboarding },
					set: { newValue in
						if !newValue {
							appModel.dismissSleepReminder()
						}
					}
				)
			) {
				Button("Okay", role: .cancel) {
					appModel.dismissSleepReminder()
				}
			} message: {
				Text("It seems quite late for you, Lumio is also going to take some rest - we shall catch up tomorrow!")
			}
	}
}


