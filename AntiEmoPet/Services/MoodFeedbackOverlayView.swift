import SwiftUI

/// 任务完成后强制情绪反馈视图
/// 提供四个反馈选项：更差、无变化、更好、好很多
struct MoodFeedbackOverlayView: View {
	
	/// 反馈选项枚举
	enum FeedbackOption: Int, CaseIterable, Identifiable {
		case worse = -5
		case unchanged = 0
		case better = 5
		case muchBetter = 10
		
		var id: Int { rawValue }
		
		var label: String {
			switch self {
			case .worse: return "Worse"
			case .unchanged: return "No Change"
			case .better: return "Better"
			case .muchBetter: return "Much Better"
			}
		}
		
		var icon: String {
			switch self {
			case .worse: return "arrow.down.circle.fill"
			case .unchanged: return "minus.circle.fill"
			case .better: return "arrow.up.circle.fill"
			case .muchBetter: return "arrow.up.circle.fill"
			}
		}
		
		var color: Color {
			switch self {
			case .worse: return .red
			case .unchanged: return .gray
			case .better: return .green
			case .muchBetter: return .blue
			}
		}
	}
	
	let taskCategory: TaskCategory
	let onComplete: (Int) -> Void
	
	@State private var selectedOption: FeedbackOption?
	
	var body: some View {
		ZStack {
			// 背景遮罩
			Color.black.opacity(0.4)
				.ignoresSafeArea()
			
			VStack(spacing: 24) {
				// 标题
				VStack(spacing: 8) {
					Image(systemName: "checkmark.circle.fill")
						.font(.system(size: 48))
						.foregroundStyle(.green)
					
					Text("Task completed!")
						.font(.title2.weight(.bold))
					
					Text("How do you feel now?")
						.font(.body)
						.foregroundStyle(.secondary)
				}
				
				// 选项按钮
				VStack(spacing: 12) {
					ForEach(FeedbackOption.allCases) { option in
						FeedbackButton(
							option: option,
							isSelected: selectedOption == option
						) {
							withAnimation(.spring(response: 0.3)) {
								selectedOption = option
							}
							// 给用户短暂的视觉反馈后自动完成
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
								onComplete(option.rawValue)
							}
						}
					}
				}
				.padding(.horizontal, 4)
			}
			.padding(32)
			.background(
				RoundedRectangle(cornerRadius: 24, style: .continuous)
					.fill(.ultraThinMaterial)
			)
			.shadow(radius: 24)
			.padding(24)
		}
	}
}

/// 反馈按钮组件
private struct FeedbackButton: View {
	let option: MoodFeedbackOverlayView.FeedbackOption
	let isSelected: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 16) {
				Image(systemName: option.icon)
					.font(.title3)
					.foregroundStyle(option.color)
					.frame(width: 32)
				
				Text(option.label)
					.font(.headline)
					.foregroundStyle(.primary)
				
				Spacer()
				
				// 选中状态指示
				if isSelected {
					Image(systemName: "checkmark")
						.font(.body.weight(.bold))
						.foregroundStyle(option.color)
						.transition(.scale.combined(with: .opacity))
				}
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 16)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(isSelected ? option.color.opacity(0.1) : Color(.systemGray6))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.strokeBorder(
						isSelected ? option.color : Color.clear,
						lineWidth: 2
					)
			)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Preview

#Preview("Mood Feedback") {
	MoodFeedbackOverlayView(taskCategory: .outdoor) { delta in
		print("Selected delta: \(delta)")
	}
}

