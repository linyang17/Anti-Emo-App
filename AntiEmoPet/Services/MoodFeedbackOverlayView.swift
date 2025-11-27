import SwiftUI
import SwiftData

/// 任务完成后强制情绪反馈视图
struct MoodFeedbackOverlayView: View {
	@EnvironmentObject private var appModel: AppViewModel
	let taskCategory: TaskCategory

	@State private var selectedOption: FeedbackOption?

	/// 反馈选项枚举
	enum FeedbackOption: Int, CaseIterable, Identifiable {
		case muchWorse = -10
		case worse = -5
		case unchanged = 0
		case better = 5
		case muchBetter = 10

		var id: Int { rawValue }

		var label: String {
			switch self {
			case .muchWorse: return "Terrible"
			case .worse: return "Worse"
			case .unchanged: return "No Change"
			case .better: return "Better"
			case .muchBetter: return "Great"
			}
		}

		// TODO: replace with facial expression image
		var icon: String {
			switch self {
			case .muchWorse: return "chevron.down.2"
			case .worse: return "chevron.down"
			case .unchanged: return "minus.circle.fill"
			case .better: return "chevron.up"
			case .muchBetter: return "chevron.up.2"
			}
		}

		var color: Color {
			switch self {
			case .muchWorse: return .red
			case .worse: return .orange
			case .unchanged: return .gray
			case .better: return .green
			case .muchBetter: return .blue
			}
		}
	}

        var body: some View {
			ZStack(alignment: .center) {
				VStack(spacing: 8) {
						
					LumioSay(text: "Feeling better?")

					HStack(spacing: 8) {
						ForEach(FeedbackOption.allCases) { option in
							FeedbackButton(option: option, isSelected: selectedOption == option) {
								withAnimation(.spring(response: 0.3)) {
										selectedOption = option
								}
								
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
										appModel.submitMoodFeedback(
														delta: option.rawValue,
														for: taskCategory
												)
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
				.font(.title.weight(.semibold))
				.foregroundStyle(.white)
				.frame(width: 66, height: 66)
		}
		.buttonStyle(.plain)
	}
}
