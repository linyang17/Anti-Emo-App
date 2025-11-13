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

    private let chatService = ChatService()
    private let analytics = AnalyticsService()
    private weak var appModel: AppViewModel?
    private var isConfigured = false

    func configureIfNeeded(appModel: AppViewModel) async {
        self.appModel = appModel
        guard !isConfigured else { return }
        isConfigured = true
        if messages.isEmpty {
            messages = [Message(role: .pet, content: "Hi，我是 Lumio！你现在感觉怎么样？要不要和我聊一聊？")]
        }
    }

    func sendCurrentMessage() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let appModel else { return }
        messages.append(Message(role: .user, content: trimmed))
        currentInput = ""
        let reply = chatService.reply(
            to: trimmed,
            weather: appModel.weather,
            bonding: appModel.pet?.bonding ?? .calm
        )
        messages.append(Message(role: .pet, content: reply))
        analytics.log(event: "chat_message")
    }
}
