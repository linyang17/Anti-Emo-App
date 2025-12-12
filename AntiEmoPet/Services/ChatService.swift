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

		func reply(to text: String, weather: WeatherType, history: [ChatMessage]) async throws -> String {
				guard let urlString = Bundle.main.infoDictionary?["SUPABASE_LUMIO_REPLY_URL"] as? String,
					  let url = URL(string: urlString) else {
						return fallbackReply(for: text, weather: weather, history: history)
				}

				var request = URLRequest(url: url)
				request.httpMethod = "POST"
				request.addValue("application/json", forHTTPHeaderField: "Content-Type")

				let payload = ServerRequest(
						text: text,
						weather: weather.rawValue,
						history: history.map { .init(role: $0.role.rawValue, content: $0.content) }
				)
				request.httpBody = try JSONEncoder().encode(payload)

				let (data, response) = try await URLSession.shared.data(for: request)
				guard let httpResponse = response as? HTTPURLResponse,
					  (200..<300).contains(httpResponse.statusCode) else {
						return fallbackReply(for: text, weather: weather, history: history)
				}

				let decoded = try JSONDecoder().decode(ServerReply.self, from: data)
				return decoded.reply.trimmingCharacters(in: .whitespacesAndNewlines)
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

				return "\(weatherLine) \(contextLine) I hear you, and I'm here with you."
		}
}

private struct ServerRequest: Codable {
		let text: String
		let weather: String
		let history: [ServerMessage]
}

private struct ServerMessage: Codable {
		let role: String
		let content: String
}

private struct ServerReply: Codable {
		let reply: String
}
