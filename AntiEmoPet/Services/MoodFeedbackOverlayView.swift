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
                ZStack(alignment: .center) {
                        // 背景遮罩
                        Color.black.opacity(0.4)
                                .ignoresSafeArea()

                        VStack(spacing: 20) {
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

                                HStack(spacing: 16) {
                                        ForEach(FeedbackOption.allCases) { option in
                                                FeedbackButton(
                                                        option: option,
                                                        isSelected: selectedOption == option
                                                ) {
                                                        withAnimation(.spring(response: 0.3)) {
                                                                selectedOption = option
                                                        }
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                                onComplete(option.rawValue)
                                                        }
                                                }
                                        }
                                }
                        }
                        .padding(28)
                        .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(.ultraThinMaterial)
                        )
                        .shadow(radius: 24)
                        .padding(.horizontal, 32)
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
                        Image(systemName: option.icon)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(option.color.opacity(0.9), in: Circle())
                                .overlay(
                                        Circle()
                                                .strokeBorder(isSelected ? Color.white.opacity(0.9) : Color.clear, lineWidth: 3)
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

