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
                .tabItem { Label("Home", systemImage: "house") }
            NavigationStack { TasksView() }
                .tabItem { Label("Tasks", systemImage: "checklist") }
            NavigationStack { PetView() }
                .tabItem { Label("Pet", systemImage: "pawprint") }
            NavigationStack { ShopView() }
                .tabItem { Label("Shop", systemImage: "cart") }
            NavigationStack { ChatView() }
                .tabItem { Label("Chat", systemImage: "message") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person") }
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
                    ChatMessage(role: .pet, content: "Hi，我是 Sunny，随时陪你聊天 ☀️")
                ]
            }
        }
    }
}
