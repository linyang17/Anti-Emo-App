import SwiftUI

struct ChatView: View {
        @EnvironmentObject private var appModel: AppViewModel
        @StateObject private var viewModel = ChatViewModel()
        @FocusState private var isInputFocused: Bool
        @State private var inputHeight: CGFloat = UIFont.preferredFont(forTextStyle: .body).lineHeight + 16

        var body: some View {
                VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                                ScrollView {
                                        LazyVStack(alignment: .leading, spacing: 12) {
                                                ForEach(viewModel.messages) { message in
                                                        let isUser = message.role == .user
                                                        HStack {
                                                                if isUser { Spacer() }
                                                                Text(message.content)
                                                                        .padding(12)
                                                                        .background(
                                                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                                                        .fill(isUser ? Color.accentColor.opacity(0.2) : Color.green.opacity(0.2))
                                                                        )
                                                                        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
                                                                if !isUser { Spacer() }
                                                        }
                                                }

                                                if viewModel.isSending, !viewModel.thinkingDots.isEmpty {
                                                        HStack {
                                                                Text(viewModel.thinkingDots)
                                                                        .appFont(FontTheme.body)
                                                                        .padding(.horizontal, 12)
                                                                        .padding(.vertical, 10)
                                                                        .background(
                                                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                                        .fill(Color.green.opacity(0.15))
                                                                        )
                                                                Spacer()
                                                        }
                                                        .id("thinking")
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
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                }
                .navigationTitle("Chat")
                .task {
                        await viewModel.configureIfNeeded(appModel: appModel)
                        isInputFocused = true
                }
        }

        private var inputBar: some View {
                let maxHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight * 3 + 16

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
                                        Text("Text here…")
                                                .foregroundStyle(.secondary)
                                                .padding(.horizontal, 18)
                                                .padding(.vertical, 16)
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
                                                        .fill(viewModel.canSend ? Color.accentColor : Color.gray)
                                        )
                        }
                        .disabled(!viewModel.canSend)
                }
        }
}

private extension ChatViewModel {
        var canSend: Bool {
                !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
        }
}
