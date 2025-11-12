import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = TasksViewModel()
    @State private var activeReward: RewardEvent?
    @State private var rewardOpacity: Double = 0
    @State private var bannerTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            List {
                Section {
                    ForEach(appModel.todayTasks) { task in
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(task.title)
                                    .font(.headline)
                                Text(viewModel.badge(for: task))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                appModel.completeTask(task)
                            } label: {
                                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.status == .completed ? .black.opacity(0.5) : .secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .disabled(task.status == .completed)
                        }
                        .padding(.vertical, 6)
                    }
                }
                if appModel.todayTasks.isEmpty {
                    Section {
                        Text("暂无任务，稍后再试或检查网络")
                    }
                }
            }
            .listStyle(.insetGrouped)

            if let reward = activeReward {
                RewardToastView(event: reward)
                    .opacity(rewardOpacity)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.isRefreshing {
                    ProgressView()
                } else {
                    Button("刷新") {
                        Task(priority: .userInitiated) { await viewModel.forceRefresh(appModel: appModel) }
                    }
                }
            }
        }
        .onChange(of: appModel.rewardBanner) { _, newValue in
            guard let reward = newValue else { return }
            activeReward = reward
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                rewardOpacity = 1
            }
            bannerTask?.cancel()
            bannerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    rewardOpacity = 0
                }
                try? await Task.sleep(nanoseconds: 350_000_000)
                activeReward = nil
                appModel.consumeRewardBanner()
            }
        }
        .onDisappear {
            bannerTask?.cancel()
        }
    }
}

private struct RewardToastView: View {
    let event: RewardEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("能量 +\(event.energy)")
                Text("经验值 +\(event.xp)")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 12)
        .padding(.horizontal, 32)
    }
}
