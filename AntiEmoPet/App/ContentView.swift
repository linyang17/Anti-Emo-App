import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appModel: AppViewModel?

    var body: some View {
        Group {
            if let appModel {
                MainTabView()
                    .environmentObject(appModel)
            } else {
                ProgressView("加载中…")
            }
        }
        .task {
            await initializeAppModelIfNeeded()
        }
    }

    @MainActor
    private func initializeAppModelIfNeeded() async {
        guard appModel == nil else { return }
        let viewModel = AppViewModel(modelContext: modelContext)
        await viewModel.load()
        appModel = viewModel
    }
}

struct MainTabView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@State private var selectedTab = "Pet" // 默认打开 Pet

	var body: some View {
		TabView(selection: $selectedTab) {
			NavigationStack { WeatherView() }
				.tabItem { Label("Weather", systemImage: "sun.max") }
				.tag("Weather")

			NavigationStack { PetView() }
				.tabItem { Label("Pet", systemImage: "pawprint") }
				.tag("Pet")

			NavigationStack { SettingsView() }
				.tabItem { Label("Settings", systemImage: "gearshape") }
				.tag("Settings")
		}
		.fullScreenCover(isPresented: Binding(
			get: { appModel.showOnboarding },
			set: { appModel.showOnboarding = $0 }
		)) {
			OnboardingView(locationService: appModel.locationService)
				.environmentObject(appModel)
		}
		.interactiveDismissDisabled(true)
                .alert("早点休息哦", isPresented: $appModel.showSleepReminder) {
                        Button("知道了", role: .cancel) { appModel.dismissSleepReminder() }
                } message: {
                        Text("已经很晚啦，Lumio建议你早点休息，明天再来哦。")
                }
        }
}
