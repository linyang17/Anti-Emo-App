import SwiftUI
import Combine

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
		
		VStack(spacing: .h(0.015)) {
			header
				.padding(.top, .h(0.03))
				.padding(.horizontal, .w(0.1))
			
			List {
				Section {
					ForEach(appModel.todayTasks) { task in
						TaskRow(task: task, appModel: appModel, viewModel: viewModel)
					}
					.listRowBackground(Color.clear)
				}
				
				if appModel.todayTasks.isEmpty {
					Section {
						Text("There's currently nothing to do for you, take some time to relax and recharge!.")
							.appFont(FontTheme.body)
					}
					.listRowBackground(Color.clear)
				}
			}
			.scrollContentBackground(.hidden) 
			.listStyle(.insetGrouped)
		}
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let report = appModel.weatherReport {
                Text(report.currentWeather.rawValue.capitalized)
                    .appFont(FontTheme.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("Weather unavailable")
                    .appFont(FontTheme.body)
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
                .appFont(FontTheme.body)
            } else if allTasksCompleted {
                Text(appModel.hasUsedRefreshThisSlot ? "You've refreshed, \n come back in the next session" : "All completed!")
                    .appFont(FontTheme.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Refresh")
                    .appFont(FontTheme.body)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
        }
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
			HStack(spacing: 4) {
				ProgressView()
					.scaleEffect(0.8)
				Text("On it...")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
		case .ready:
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
			Image(systemName: "checkmark.circle.fill")
				.font(.subheadline.weight(.medium))
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
			HStack(spacing: 4) {
				Image(systemName: "sparkles")
					.foregroundStyle(.yellow)
				
				VStack(alignment: .leading, spacing: 2) {
					LumioSay(text: "Energy +\(event.energy)  Xp +\(event.xp)")
					if let snack = event.snackName {
						LumioSay(text: "You got some \(snack) in the bag!")
					}
				}
			}
			.padding(12)
			.shadow(radius: 6)
		}
	}
