import SwiftUI

struct ChatView: View {
        @EnvironmentObject private var appModel: AppViewModel
        @StateObject private var viewModel = ChatViewModel()

        var body: some View {
                VStack {
                        ScrollViewReader { proxy in
                                ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 12) {
                                                ForEach(viewModel.messages) { message in
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
                                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                                        guard newValue != oldValue else { return }
                                        if let last = viewModel.messages.last {
                                                proxy.scrollTo(last.id, anchor: .bottom)
                                        }
                                }
                        }

                        // 底部输入栏
                        HStack {
                                TextField("Text here…", text: $viewModel.currentInput)
                                        .textFieldStyle(.roundedBorder)
                                Button("Send") {
                                        viewModel.sendCurrentMessage()
                                }
                                .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding()
                }
                .navigationTitle("Chat")
                .task {
                        await viewModel.configureIfNeeded(appModel: appModel)
                }
        }
}
