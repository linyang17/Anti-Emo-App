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
        .task { @MainActor in
            initializeAppModelIfNeeded()
        }
    }

    @MainActor
    private func initializeAppModelIfNeeded() {
        guard appModel == nil else { return }
        let viewModel = AppViewModel(modelContext: modelContext)
        viewModel.load()
        appModel = viewModel
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Weather", systemImage: "sun.max") }
            NavigationStack { TasksView() }
                .tabItem { Label("Tasks", systemImage: "checklist") }
            NavigationStack { PetView() }
                .tabItem { Label("Pet", systemImage: "pawprint") }
            NavigationStack { ShopView() }
                .tabItem { Label("Shop", systemImage: "cart") }
            NavigationStack { ChatView() }
                .tabItem { Label("Chat", systemImage: "message") }
            NavigationStack { StatisticsView() }
                .tabItem { Label("Statistics", systemImage: "chart.line.uptrend.xyaxis") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
            NavigationStack { MoreView() }
                .tabItem { Label("More", systemImage: "ellipsis") }
        }
        .sheet(isPresented: Binding(
            get: { appModel.showOnboarding },
            set: { appModel.showOnboarding = $0 }
        )) {
            OnboardingView()
                .environmentObject(appModel)
        }
        .onAppear {
            if appModel.chatMessages.isEmpty {
                appModel.chatMessages = [
                    ChatMessage(role: .pet, content: "Hi，我是Sunny，你现在感觉怎么样？要不要和我聊一聊？")
                ]
            }
        }
    }
}
