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
    let lastMood: Int

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            
            VStack(spacing: 0) {
                header
					.padding(12)
                
                ZStack(alignment: .top) {
                    List {
                    Section {
                        ForEach(appModel.todayTasks) { task in
                            TaskRow(task: task, appModel: appModel, viewModel: viewModel)
                        }
                    }
                    if appModel.todayTasks.isEmpty {
                        Section {
                            Text("There's currently nothing to do for you, take some time to relax and recharge!.")
                                .appFont(FontTheme.body)
                        }
                    }
                }
                .listStyle(.insetGrouped)

            }
        }
    }
}

    private var header: some View {
        HStack(spacing: 8) {
            if let report = appModel.weatherReport {
                Text(report.currentWeather.rawValue.capitalized)
                    .appFont(FontTheme.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Weather unavailable")
                    .appFont(FontTheme.caption)
                    .foregroundStyle(.secondary)
            }

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
                        .padding(12)
                }
                .appFont(FontTheme.footnote)
            } else if allTasksCompleted {
                Text(appModel.hasUsedRefreshThisSlot ? "You've refreshed, come back in the next session" : "All completed!")
                    .appFont(FontTheme.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Refresh")
                    .appFont(FontTheme.footnote)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
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
		@State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

	var body: some View {
			HStack {
				VStack(alignment: .leading, spacing: 6) {
					Text(task.title)
						.appFont(FontTheme.body)
					HStack {
						Text(task.category.title)
							.appFont(FontTheme.caption)
							.foregroundStyle(.secondary)
						Text(viewModel.badge(for: task))
							.appFont(FontTheme.caption)
							.foregroundStyle(.secondary)
					}
				}
				Spacer()
				VStack {
					if task.status == .started, let canComplete = task.canCompleteAfter {
						Text(formatRemainingTime(remainingTime > 0 ? remainingTime : canComplete.timeIntervalSinceNow))
							.appFont(FontTheme.caption)
							.foregroundStyle(.orange)
					}
					taskActionButton
				}
			}
			.padding(.vertical, 6)
			.onAppear {
				remainingTime = max(0, task.canCompleteAfter?.timeIntervalSinceNow ?? 0)
			}
			.onReceive(timer) { _ in
				guard task.status == .started, let canComplete = task.canCompleteAfter else { return }
				remainingTime = max(0, canComplete.timeIntervalSinceNow)
				if remainingTime <= 0 {
					appModel.updateTaskStatus(task.id, to: .ready)
				}
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
				Text("Start")
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
				Text("On it...")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
		case .ready:
			// 可以完成 - 显示"完成"按钮
			Button {
				appModel.completeTask(task)
			} label: {
				Text("Done!")
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
	
        private func formatRemainingTime(_ interval: TimeInterval) -> String {
                let remaining = max(0, interval)
                let minutes = Int(remaining) / 60
                let seconds = Int(remaining) % 60
		
		if minutes > 0 {
			return String(format: "%d:%02d", minutes, seconds)
		} else {
			return String(format: "00:%02d", seconds)
		}
	}
	
}

struct RewardToastView: View {
    let event: RewardEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Energy +\(event.energy)")
                Text("Xp +\(event.xp)")
                if let snack = event.snackName {
                    Text("You got \(snack) in the bag!")
                        .font(.caption2)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 12)
        .padding(.horizontal, 32)
    }
}
