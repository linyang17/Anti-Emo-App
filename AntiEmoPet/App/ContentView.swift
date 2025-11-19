import SwiftUI
import SwiftData

struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@State private var appModel: AppViewModel?
	@State private var showWelcome = false

	var body: some View {
		Group {
			if let appModel {
				MainTabView()
					.environmentObject(appModel)
			} else {
				ProgressView("Loading…")
			}
		}
		.task {
			await initializeAppModelIfNeeded()
		}
		.fullScreenCover(isPresented: $showWelcome) {
			if let appModel {
				WelcomeView {
					showWelcome = false
				}
				.environmentObject(appModel)
			} else {
				EmptyView()
			}
		}
	}

	@MainActor
	private func initializeAppModelIfNeeded() async {
		guard appModel == nil else { return }
		let viewModel = AppViewModel(modelContext: modelContext)
		await viewModel.load()
		appModel = viewModel
		if viewModel.userStats?.Onboard == true {
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
					.environmentObject(appModel)
			}
                        .interactiveDismissDisabled(true)
                        // 每日首次打开时强制情绪记录弹窗
                        .fullScreenCover(isPresented: Binding(
                                get: { appModel.showMoodCapture && !appModel.showOnboarding },
                                set: { newValue in
                                        if !appModel.shouldForceMoodCapture {
                                                appModel.showMoodCapture = newValue
                                        }
                                }
                        )) {
                                ZStack {
                                        MoodCaptureOverlayView() { value in
                                                appModel.recordMoodOnLaunch(value: value)
                                        }
                                }
                        }
                        .interactiveDismissDisabled(appModel.shouldForceMoodCapture && !appModel.showOnboarding)
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
