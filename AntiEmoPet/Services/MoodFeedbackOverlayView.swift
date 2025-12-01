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

		var icon: String {
			switch self {
			case .muchWorse: return "mood-facepalm"
			case .worse: return "mood-upset"
			case .unchanged: return "mood-calm"
			case .better: return "mood-wink"
			case .muchBetter: return "mood-laugh"
			}
		}
	}

        var body: some View {
			ZStack(alignment: .center) {
				VStack(spacing: 20) {
						
					LumioSay(text: "Feeling better?")

					HStack(spacing: 12) {
						ForEach(FeedbackOption.allCases) { option in
							FeedbackButton(option: option, isSelected: selectedOption == option) {
								withAnimation(.spring(response: 0.7)) {
										selectedOption = option
								}
								
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
                }
        }
	
}

/// 反馈按钮组件
struct FeedbackButton: View {
	let option: MoodFeedbackOverlayView.FeedbackOption
	let isSelected: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Image(option.icon)
				.resizable()
				.scaledToFit()
				.frame(width: 45, height: 45)
				.opacity(0.75)
		}
		.buttonStyle(.plain)
	}
}
