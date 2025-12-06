import Foundation

struct ChatService {
        struct ChatMessage: Codable, Equatable {
                enum Role: String, Codable {
                        case user
                        case assistant
                        case system
                }

                let role: Role
                let content: String
        }

        enum ChatServiceError: Error {
                case missingAPIKey
                case invalidResponse
        }

        private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        private let model = "gpt-4o-mini"

        func reply(to text: String, weather: WeatherType, history: [ChatMessage]) async throws -> String {
                guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
                        return fallbackReply(for: text, weather: weather, history: history)
                }

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                var messages = [ChatMessage(role: .system, content: systemPrompt(for: weather))]
                messages.append(contentsOf: history)
                messages.append(ChatMessage(role: .user, content: text))

                let payload = ChatRequest(model: model, messages: messages)
                request.httpBody = try JSONEncoder().encode(payload)

                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        return fallbackReply(for: text, weather: weather, history: history)
                }

                guard let choice = try JSONDecoder().decode(ChatCompletionResponse.self, from: data).choices.first else {
                        throw ChatServiceError.invalidResponse
                }
                return choice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func systemPrompt(for weather: WeatherType) -> String {
                "You are Lumio, a supportive pet friend. Keep answers concise, empathetic, and tailor to the current weather: \(weather.rawValue)."
        }

        private func fallbackReply(for text: String, weather: WeatherType, history: [ChatMessage]) -> String {
                let lastContext = history.last { $0.role == .assistant }?.content ?? "I'm here for you."
                let weatherLine: String
                switch weather {
                case .sunny: weatherLine = "今天是晴天，阳光会带来一点好心情。"
                case .rainy: weatherLine = "外面下雨了，我们可以找点室内的小事做。"
                case .snowy: weatherLine = "飘着雪呢，记得保暖。"
                case .cloudy: weatherLine = "有点阴天，但我在听着你。"
                case .windy: weatherLine = "今天有风，把烦恼吹散吧。"
                }
                return "\(weatherLine) 你说的\(text)，我都听见了。"
        }
}

private struct ChatRequest: Codable {
        let model: String
        let messages: [ChatService.ChatMessage]
		var temperature: Double = 1
}

private struct ChatCompletionResponse: Codable {
        struct Choice: Codable {
                let index: Int
                let message: ChatService.ChatMessage
        }

        let choices: [Choice]
}
