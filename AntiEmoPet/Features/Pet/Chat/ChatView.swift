import SwiftUI

struct ChatView: View {
        @EnvironmentObject private var appModel: AppViewModel
        @StateObject private var viewModel = ChatViewModel()
        @FocusState private var isInputFocused: Bool
        @State private var inputHeight: CGFloat = UIFont.preferredFont(forTextStyle: .body).lineHeight + 16
        @State private var hasInjectedComfortMessage = false

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
									ForEach(viewModel.messages) { message in
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
                let maxHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight * 1

                return HStack(alignment: .bottom, spacing: 12) {
                        ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )

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
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 16)
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
                                                        .fill(viewModel.canSend ? Color.accentColor : Color.gray.opacity(0.5))
                                        )
                        }
                        .disabled(!viewModel.canSend)
                }
        }
}

private struct MessageBubble: View {
        let message: ChatViewModel.Message

        private var isUser: Bool { message.role == .user }

        var body: some View {
                HStack(alignment: .bottom, spacing: 10) {
                        if isUser { Spacer() }

                        if !isUser { avatar }

						Text(message.content)
							.padding(.horizontal, 14)
							.padding(.vertical, 12)
							.background(
								RoundedRectangle(cornerRadius: 18, style: .continuous)
										.fill(isUser ? Color.accentColor : Color.white.opacity(0.9))
										.shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                                        )
							.frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)

                        if isUser { avatar }
                }
                .frame(maxWidth: .infinity)
        }

	// TODO: let user upload profile picture into avatar
	private var avatar: some View {
		Image(systemName: isUser ? "person.circle.fill" : "pawprint.circle.fill")
			.resizable()
			.scaledToFit()
			.frame(width: 30, height: 30)
			.foregroundStyle(isUser ? Color.gray : Color.brown)
	}
}

private extension ChatViewModel {
        var canSend: Bool {
                !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
        }
}
