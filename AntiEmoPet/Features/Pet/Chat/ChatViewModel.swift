import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    struct Message: Identifiable, Equatable, Codable {
        enum Role: String, Codable {
            case user
            case pet
        }

        let id: UUID
        let role: Role
        let content: String
        let createdAt: Date
        let isSystem: Bool

        init(role: Role, content: String, createdAt: Date = .now, isSystem: Bool = false, id: UUID = UUID()) {
            self.id = id
            self.role = role
            self.content = content
            self.createdAt = createdAt
            self.isSystem = isSystem
        }
    }

    @Published var currentInput: String = ""
    @Published var messages: [Message] = [] {
        didSet { persistHistory() }
    }
    @Published var isSending = false
    @Published var thinkingDots: String = ""

    private let chatService = ChatService()
    private let analytics = AnalyticsService()
    private weak var appModel: AppViewModel?
    private var isConfigured = false
    private var thinkingTask: Task<Void, Never>?
    private let historyKey = "chat.history"
    private let usageKey = "chat.usage"
    private let dayFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
			formatter.formatOptions = [.withFullDate]
			formatter.timeZone = TimeZone(secondsFromGMT: 0)
		return formatter
    }()

    func configureIfNeeded(appModel: AppViewModel) async {
        self.appModel = appModel
        guard !isConfigured else { return }
        isConfigured = true

        messages = loadHistory()
        if messages.isEmpty {
            messages = [Message(role: .pet, content: "Hi, it's Lumio here！How do you feel right now? Feel free if you want to talk about anything, I'm always here to listen!", isSystem: true)]
        }
    }

    func sendCurrentMessage() {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let appModel else { return }
        messages.append(Message(role: .user, content: trimmed))
        currentInput = ""

        guard responsesToday() < 3 else {
            messages.append(Message(role: .pet, content: overLimitMessage(), isSystem: true))
            return
        }

        Task { @MainActor in
            isSending = true
            startThinkingAnimation()
            defer {
                stopThinkingAnimation()
                isSending = false
            }

            do {
                let reply = try await chatService.reply(
                    to: trimmed,
                    weather: appModel.weather,
                    history: chatHistory()
                )
                messages.append(Message(role: .pet, content: reply))
                incrementUsage()
            } catch {
                messages.append(Message(role: .pet, content: "Lumio is having trouble replying right now, but I'm still here.", isSystem: true))
            }
            analytics.log(event: "chat_message")
        }
    }

    func insertComfortMessage(for moodValue: Int) {
        let message = Message(role: .pet, content: comfortMessage(for: moodValue), isSystem: true)
        messages.append(message)
    }

    private func comfortMessage(for moodValue: Int) -> String {
        switch moodValue {
        case ..<35:
            return "That sounds really tough. I'm here with you. Even tiny steps, like a deep breath or stretching, can be a start."
        case 35..<70:
            return "Thanks for sharing how you feel. I'm here to listen if you want to unpack it more, or we can take a gentle break together."
        default:
            return "I'm glad you're feeling lighter. Let's keep this good rhythm going—anything you'd like to talk about or celebrate?"
        }
    }

    private func startThinkingAnimation() {
        thinkingTask?.cancel()
        thinkingTask = Task { @MainActor in
            var count = 1
            while !Task.isCancelled {
                thinkingDots = String(repeating: ".", count: count)
                count = count >= 6 ? 1 : count + 1
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
    }

    private func stopThinkingAnimation() {
        thinkingTask?.cancel()
        thinkingTask = nil
        thinkingDots = ""
    }

    private func chatHistory() -> [ChatService.ChatMessage] {
        messages
            .filter { !$0.isSystem }
            .map { message in
                let role: ChatService.ChatMessage.Role = message.role == .user ? .user : .assistant
                return ChatService.ChatMessage(role: role, content: message.content)
            }
    }

    private func responsesToday() -> Int {
        guard let data = UserDefaults.standard.data(forKey: usageKey),
              let record = try? JSONDecoder().decode(UsageRecord.self, from: data),
              record.day == dayKey(for: Date()) else { return 0 }
        return record.count
    }

    private func incrementUsage() {
        let today = dayKey(for: Date())
        var record = (try? JSONDecoder().decode(UsageRecord.self, from: UserDefaults.standard.data(forKey: usageKey) ?? Data())) ?? UsageRecord(day: today, count: 0)
        if record.day != today {
            record = UsageRecord(day: today, count: 0)
        }
        record.count += 1
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: usageKey)
        }
    }

    private func overLimitMessage() -> String {
        "You've reached today's chat limit. Let's continue tomorrow!"
    }

    private func loadHistory() -> [Message] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([Message].self, from: data)) ?? []
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(messages) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func dayKey(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private struct UsageRecord: Codable {
        let day: String
        var count: Int
    }
}
