import SwiftUI

struct ChatView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var viewModel = ChatViewModel()

	var body: some View {
		VStack {
			ScrollViewReader { proxy in
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 12) {
						ForEach(appModel.chatMessages) { message in
							HStack {
								if message.role == .pet { Spacer() }
								Text(message.content)
									.padding(12)
									.background(
										RoundedRectangle(cornerRadius: 12)
											.fill(message.role == .user
												  ? Color.accentColor.opacity(0.2)
												  : Color.green.opacity(0.2))
									)
								if message.role == .user { Spacer() }
							}
						}
					}
					.padding()
				}
				.onChange(of: appModel.chatMessages.count) { oldValue, newValue in
					guard newValue != oldValue else { return }
					if let last = appModel.chatMessages.last {
						proxy.scrollTo(last.id, anchor: .bottom)
					}
				}
			}

			// 底部输入栏
			HStack {
				TextField("输入想说的话…", text: $viewModel.currentInput)
					.textFieldStyle(.roundedBorder)
				Button("发送") {
					appModel.sendChat(viewModel.currentInput)
					viewModel.currentInput = ""
				}
				.disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
			}
			.padding()
		}
		.navigationTitle("Chat")
		// 打开 ChatView 时加载初始消息
		.onAppear {
			if appModel.chatMessages.isEmpty {
				appModel.chatMessages = [
					ChatMessage(role: .pet, content: "Hi，我是 Lumio！你现在感觉怎么样？要不要和我聊一聊？")
				]
			}
		}
	}
}
