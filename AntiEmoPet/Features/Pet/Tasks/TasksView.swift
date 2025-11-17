import SwiftUI


struct RewardEvent: Identifiable, Equatable {
	let id = UUID()
	let energy: Int
	let xp: Int
	let snackName: String?

	init(energy: Int, xp: Int, snackName: String? = nil) {
		self.energy = energy
		self.xp = xp
		self.snackName = snackName
	}
}

struct TasksView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = TasksViewModel()
    @State private var activeReward: RewardEvent?
    @State private var rewardOpacity: Double = 0
    @State private var bannerTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                
                ZStack(alignment: .top) {
                    List {
                    Section {
                        ForEach(appModel.todayTasks) { task in
                            TaskRow(task: task, appModel: appModel, viewModel: viewModel)
                        }
                    }
                    if appModel.todayTasks.isEmpty {
                        Section {
                            Text("当前时段暂无任务，请稍候或留意 Lumio 的通知。")
                                .appFont(FontTheme.body)
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
            
            // 任务完成后的情绪反馈弹窗
            if let task = appModel.pendingMoodFeedbackTask {
                MoodFeedbackOverlayView(taskCategory: task.category) { delta in
                    appModel.submitMoodFeedback(delta: delta, for: task)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(999)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Tasks")
                .appFont(FontTheme.title2)
                .foregroundStyle(.primary)
            Spacer()
            if viewModel.isRefreshing {
                ProgressView()
            } else if appModel.canRefreshCurrentSlot {
                Button {
                    Task(priority: .userInitiated) {
                        await viewModel.forceRefresh(appModel: appModel)
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                }
                .appFont(FontTheme.caption)
            } else if allTasksCompleted {
                Text(appModel.hasUsedRefreshThisSlot ? "本时段刷新次数已用" : "完成奖励已结算")
                    .appFont(FontTheme.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("完成全部任务可刷新一次")
                    .appFont(FontTheme.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var allTasksCompleted: Bool {
        !appModel.todayTasks.isEmpty && appModel.todayTasks.allSatisfy { $0.status == .completed }
    }
}

/// 任务行组件 - 显示不同状态的按钮和倒计时
private struct TaskRow: View {
	let task: UserTask
	let appModel: AppViewModel
	let viewModel: TasksViewModel
	@State private var remainingTime: TimeInterval = 0
	@State private var timer: Timer?
	
	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 6) {
				Text(task.title)
					.appFont(FontTheme.headline)
				Text(viewModel.badge(for: task))
					.appFont(FontTheme.caption)
					.foregroundStyle(.secondary)
				
				// 显示倒计时
				if task.status == .started, let canComplete = task.canCompleteAfter {
					Text(formatRemainingTime(until: canComplete))
						.appFont(FontTheme.caption)
						.foregroundStyle(.orange)
				}
			}
			Spacer()
			
			// 根据状态显示不同按钮
			taskActionButton
		}
		.padding(.vertical, 6)
		.onAppear {
			startTimerIfNeeded()
		}
		.onDisappear {
			stopTimer()
		}
	}
	
	@ViewBuilder
	private var taskActionButton: some View {
		switch task.status {
		case .pending:
			// 未开始 - 显示"开始"按钮
			Button {
				appModel.startTask(task)
			} label: {
				Text("开始")
					.font(.subheadline.weight(.medium))
					.foregroundStyle(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
					.background(.blue, in: Capsule())
			}
			.buttonStyle(.plain)
			
		case .started:
			// 已开始但未到时间 - 显示等待图标
			HStack(spacing: 4) {
				ProgressView()
					.scaleEffect(0.8)
				Text("等待中")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
		case .ready:
			// 可以完成 - 显示"完成"按钮
			Button {
				appModel.completeTask(task)
			} label: {
				Text("完成")
					.font(.subheadline.weight(.medium))
					.foregroundStyle(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
					.background(.green, in: Capsule())
			}
			.buttonStyle(.plain)
			
		case .completed:
			// 已完成 - 显示完成图标
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(.black.opacity(0.5))
				.imageScale(.large)
		}
	}
	
	private func formatRemainingTime(until date: Date) -> String {
		let remaining = max(0, date.timeIntervalSinceNow)
		let minutes = Int(remaining) / 60
		let seconds = Int(remaining) % 60
		
		if minutes > 0 {
			return String(format: "还需 %d:%02d", minutes, seconds)
		} else {
			return String(format: "还需 %d秒", seconds)
		}
	}
	
	private func startTimerIfNeeded() {
		guard task.status == .started, let canComplete = task.canCompleteAfter else { return }
		
		timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
			remainingTime = max(0, canComplete.timeIntervalSinceNow)
			if remainingTime <= 0 {
				stopTimer()
			}
		}
	}
	
	private func stopTimer() {
		timer?.invalidate()
		timer = nil
	}
}

private struct RewardToastView: View {
    let event: RewardEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Energy +\(event.energy)")
                Text("Xp +\(event.xp)")
				if let snack = event.snackName {
					Text("获得零食：\(snack)")
						.font(.caption2)
				}
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 12)
        .padding(.horizontal, 32)
    }
}
