import Foundation

/// JSON 结构
private struct GreetingTemplatesPayload: Decodable {
	let base: [String: [String]]
	let weather: [String: [String]]
	let mood: [String: [String]]
}

/// 负责从 JSON 加载 & 提供访问 API 的模板存储
final class GreetingTemplateStore {

	static let shared = GreetingTemplateStore()

	private let templates: GreetingTemplatesPayload

	init(bundle: Bundle = .main) {
		guard
			let url = bundle.url(forResource: "GreetingTemplates", withExtension: "json"),
			let data = try? Data(contentsOf: url),
			let payload = try? JSONDecoder().decode(GreetingTemplatesPayload.self, from: data)
		else {
			self.templates = GreetingTemplatesPayload(
				base: [:],
				weather: [:],
				mood: [:]
			)
			assertionFailure("⚠️ Failed to load GreetingTemplates.json")
			return
		}

		self.templates = payload
	}

	// MARK: - 公开 API

	func baseTemplates(for slot: TimeSlot) -> [String] {
		templates.base[slot.rawValue] ?? []
	}

	func weatherTemplates(for type: WeatherType) -> [String] {
		templates.weather[type.rawValue] ?? []
	}

	func moodTemplates(for level: MoodLevel) -> [String] {
		templates.mood[level.rawValue] ?? []
	}

	func render(_ template: String, name: String) -> String {
		template.replacingOccurrences(of: "{name}", with: name)
	}
}
