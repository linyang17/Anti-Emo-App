import SwiftUI

struct ChatView: View {
		@EnvironmentObject private var appModel: AppViewModel
		@StateObject private var viewModel = ChatViewModel()
		@FocusState private var isInputFocused: Bool
		@State private var inputHeight: CGFloat = (UIFont(name: "ABeeZee-Regular", size: FontTheme.body.size)?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight) * 2
		@State private var hasInjectedComfortMessage = false
		private let calendar = TimeZoneManager.shared.calendar
		private let dateFormatter: DateFormatter = {
				let formatter = DateFormatter()
				formatter.dateStyle = .medium
				return formatter
		}()

		let initialComfortMood: Int?

		init(initialComfortMood: Int? = nil) {
				self.initialComfortMood = initialComfortMood
		}

		var body: some View {
				ZStack {

					VStack(spacing: 0) {
						ScrollViewReader { proxy in
							ScrollView {
								LazyVStack(alignment: .leading, spacing: 16) {
									ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
										if shouldShowDateSeparator(at: index) {
											ChatDateSeparator(text: formattedDate(message.createdAt))
										}
										MessageBubble(message: message)
										}

										if viewModel.isSending, !viewModel.thinkingDots.isEmpty {
											HStack(alignment: .bottom) {
												MessageBubble(message: .init(role: .pet, content: viewModel.thinkingDots, isSystem: true))
													.id("thinking")
													Spacer()
												}
											}
										}
										.padding(.horizontal)
										.padding(.top, 12)
										.padding(.bottom, 8)
								}
								.onChange(of: viewModel.messages.count) { oldValue, newValue in
												guard newValue != oldValue else { return }
												if let last = viewModel.messages.last {
														proxy.scrollTo(last.id, anchor: .bottom)
												}
										}
										.onChange(of: viewModel.isSending) { _, isSending in
												guard isSending, let last = viewModel.messages.last else { return }
												proxy.scrollTo(last.id, anchor: .bottom)
										}
										.onChange(of: viewModel.thinkingDots) { _, _ in
												guard viewModel.isSending else { return }
												proxy.scrollTo("thinking", anchor: .bottom)
										}
								}

								inputBar
										.padding(.horizontal)
										.padding(.vertical, 14)
										.background(.ultraThinMaterial)
						}
				}
				.navigationTitle("Chat")
				.task {
						await viewModel.configureIfNeeded(appModel: appModel)
						if let comfort = initialComfortMood, !hasInjectedComfortMessage {
								viewModel.insertComfortMessage(for: comfort)
								hasInjectedComfortMessage = true
						}

						DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
								isInputFocused = true
						}
				}
		}

		private var inputBar: some View {
				let baseLineHeight = UIFont(name: "ABeeZee-Regular", size: FontTheme.body.size)?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
				let maxHeight = baseLineHeight * 1

				return HStack(alignment: .bottom, spacing: 12) {
						ZStack(alignment: .topLeading) {

								GrowingTextView(
										text: $viewModel.currentInput,
										calculatedHeight: $inputHeight,
										isFocused: Binding<Bool>(
												get: { isInputFocused },
												set: { isInputFocused = $0 }
										),
										maxHeight: maxHeight
								) {
										viewModel.sendCurrentMessage()
								}
								.frame(height: inputHeight)
								.focused($isInputFocused)
								.padding(2)

								if viewModel.currentInput.isEmpty {
										Text("Text here")
												.foregroundStyle(.secondary)
												.padding(.horizontal, 16)
												.appFont(FontTheme.body)
												.allowsHitTesting(false)
								}
						}
						.onTapGesture { isInputFocused = true }

						Button {
								viewModel.sendCurrentMessage()
								isInputFocused = true
						} label: {
								Image(systemName: "paperplane.fill")
										.font(.title3.weight(.semibold))
										.foregroundStyle(.white)
										.padding(12)
										.background(
												Circle()
													.fill(viewModel.canSend ? Color.accentColor.opacity(0.8) : Color.gray.opacity(0.5))
										)
						}
						.disabled(!viewModel.canSend)
				}
		}
}

private struct ChatDateSeparator: View {
		let text: String

		var body: some View {
				HStack {
						Spacer()
						Text(text)
								.appFont(FontTheme.caption)
								.foregroundStyle(.secondary)
								.padding(.vertical, 6)
						Spacer()
				}
		}
}

private struct MessageBubble: View {
		let message: ChatViewModel.Message

		private var isUser: Bool { message.role == .user }

		var body: some View {
			HStack(alignment: .bottom, spacing: 8) {
					if !isUser {
							avatar
							textbubble
							Spacer()
					} else {
							Spacer()
							textbubble
					}
				}
				.frame(maxWidth: .infinity)
		}
	
	private var textbubble: some View {
			Text(message.content)
					.appFont(FontTheme.body)
					.padding(.horizontal, 14)
					.padding(.vertical, 8)
					.foregroundColor(isUser ? Color.white : Color.primary)
					.background(
							RoundedRectangle(cornerRadius: 18, style: .continuous)
									.fill(isUser ? Color.blue : Color(.secondarySystemBackground))
					)
					.frame(maxWidth: UIScreen.main.bounds.width * 0.75,
						   alignment: isUser ? .trailing : .leading)
	}


	// TODO: let user upload profile picture into avatar
	
	private var avatar: some View {
		Image(systemName: "pawprint.circle.fill")
			.resizable()
			.scaledToFit()
			.frame(width: 30, height: 30)
			.foregroundStyle(Color.brown)
	}
}

private extension ChatViewModel {
		var canSend: Bool {
				!currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
		}
}

private extension ChatView {
		func formattedDate(_ date: Date) -> String {
				dateFormatter.string(from: date)
		}

		func shouldShowDateSeparator(at index: Int) -> Bool {
				guard index < viewModel.messages.count else { return false }
				guard index > 0 else { return true }
				let previous = viewModel.messages[index - 1]
				return !calendar.isDate(previous.createdAt, inSameDayAs: viewModel.messages[index].createdAt)
		}
}
