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
                                            .fill(message.role == .user ? Color.accentColor.opacity(0.2) : Color.green.opacity(0.2))
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

            HStack {
                TextField("输入想说的话…", text: $viewModel.currentInput)
                    .textFieldStyle(.roundedBorder)
                    // TODO(中/EN): Hook to real LLM endpoint (ChatService) with typing indicator + personas.
                Button("发送") {
                    appModel.sendChat(viewModel.currentInput)
                    viewModel.currentInput = ""
                }
                .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .energyToolbar(appModel: appModel)
        .navigationTitle("Chat")
    }
}

