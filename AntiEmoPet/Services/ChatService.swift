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
        private let replyPrompt = "Respond in warm, concise English (under 70 words). Encourage small, doable steps, avoid clinical language, and never ask for sensitive personal details."

        func reply(to text: String, weather: WeatherType, history: [ChatMessage]) async throws -> String {
                guard let apiKey = resolveAPIKey() else {
                        return fallbackReply(for: text, weather: weather, history: history)
                }

                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                var messages = [
                        ChatMessage(role: .system, content: systemPrompt(for: weather)),
                        ChatMessage(role: .system, content: replyPrompt),
                ]
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

        private func resolveAPIKey() -> String? {
                if let dotEnvKey = loadAPIKeyFromDotEnv(), !dotEnvKey.isEmpty {
                        return dotEnvKey
                }

                if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
                        return envKey
                }

                if let plistKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String, !plistKey.isEmpty {
                        return plistKey
                }

                return nil
        }

        private func loadAPIKeyFromDotEnv() -> String? {
                guard let envURL = Bundle.main.url(forResource: ".env", withExtension: nil) else {
                        return nil
                }

                guard let contents = try? String(contentsOf: envURL, encoding: .utf8) else {
                        return nil
                }

                for line in contents.split(whereSeparator: \.isNewline) {
                        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

                        guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else { continue }

                        let parts = trimmedLine.split(separator: "=", maxSplits: 1).map(String.init)
                        guard parts.count == 2 else { continue }

                        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                        if key == "OPENAI_API_KEY" {
                                return value
                        }
                }

                return nil
        }

        private func fallbackReply(for text: String, weather: WeatherType, history: [ChatMessage]) -> String {
                let lastContext = history.last { $0.role == .assistant }?.content
                let weatherLine: String
                switch weather {
                case .sunny: weatherLine = "It's sunny today—let the light lift you up a little."
                case .rainy: weatherLine = "It's raining outside; maybe we can find a cozy indoor activity."
                case .snowy: weatherLine = "Snow is falling, so stay warm and take it slow."
                case .cloudy: weatherLine = "It's a bit cloudy, but I'm right here listening."
                case .windy: weatherLine = "It's windy today; imagine the breeze carrying worries away."
                }
                let contextLine = lastContext.map { "Earlier I shared: \"\($0)\". That still holds." } ?? "I'm here for you."

                return "\(weatherLine) \(contextLine) You mentioned \"\(text)\"—I hear you, and I'm with you."
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
