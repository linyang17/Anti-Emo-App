import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    struct Message: Identifiable, Equatable {
        enum Role {
            case user
            case pet
        }

        let id = UUID()
        let role: Role
        let content: String
        let createdAt: Date

        init(role: Role, content: String, createdAt: Date = .now) {
            self.role = role
            self.content = content
            self.createdAt = createdAt
        }
    }

    @Published var currentInput: String = ""
    @Published var messages: [Message] = []
    @Published var isSending = false

    private let chatService = ChatService()
    private let analytics = AnalyticsService()
    private weak var appModel: AppViewModel?
    private var isConfigured = false

    func configureIfNeeded(appModel: AppViewModel) async {
        self.appModel = appModel
        guard !isConfigured else { return }
        isConfigured = true
        if messages.isEmpty {
            messages = [Message(role: .pet, content: "Hi, it's Lumio here！How do you feel right now? Feel free if you want to talk about anything, I'm always here to listen!")]
        }
    }

    func sendCurrentMessage() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let appModel else { return }
        messages.append(Message(role: .user, content: trimmed))
        currentInput = ""

        Task { @MainActor in
                isSending = true
                do {
                        let reply = try await chatService.reply(
                                to: trimmed,
                                weather: appModel.weather,
                                history: chatHistory()
                        )
                        messages.append(Message(role: .pet, content: reply))
                } catch {
                        messages.append(Message(role: .pet, content: "Lumio is having trouble replying right now, but I'm still here."))
                }
                analytics.log(event: "chat_message")
                isSending = false
        }
    }

    private func chatHistory() -> [ChatService.ChatMessage] {
            messages.map { message in
                    let role: ChatService.ChatMessage.Role = message.role == .user ? .user : .assistant
                    return ChatService.ChatMessage(role: role, content: message.content)
            }
    }
}
