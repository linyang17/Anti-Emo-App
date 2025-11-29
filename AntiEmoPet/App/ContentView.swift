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
                .onChange(of: appModel.isLoading) { _, isLoading in
                        if !isLoading {
                                evaluateWelcomeDisplay()
                        }
                }
                .overlay {
                    if showWelcome {
                        WelcomeView {
                            withAnimation(.easeInOut(duration: 0.35)) { showWelcome = false }
                        }
						.transition(.opacity)
                        .ignoresSafeArea()
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: showWelcome)
	}

	private func evaluateWelcomeDisplay() {
	    guard let onboarded = appModel.userStats?.Onboard else { return }
	    // Only show global welcome when not in onboarding flow
	    showWelcome = onboarded && !appModel.showOnboarding
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
		.sleepReminder(isPresented: sleepAlertBinding) {
			appModel.dismissSleepReminder()
		}
	}
}
