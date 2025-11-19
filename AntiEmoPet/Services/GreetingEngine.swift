import Foundation

/// Greeting 可选类别：基础 / 天气 / 情绪
enum GreetingFlavor: CaseIterable {
	case base
	case weather
	case mood
}

/// 将 WelcomeView 里的问候上下文抽象成独立结构
struct GreetingContext {
	let name: String
	let timeSlot: TimeSlot
	let weather: WeatherType?
	let lastMood: Int?
}

/// 问候引擎：根据上下文和静态模板生成一条最终文案
enum GreetingEngine {

	static func makeGreeting(from context: GreetingContext) -> String {
		let name = context.name.isEmpty ? "my friend" : context.name

		var availableFlavors: [GreetingFlavor] = [.base]

		if context.weather != nil {
			availableFlavors.append(.weather)
		}
		if context.lastMood != nil {
			availableFlavors.append(.mood)
		}

		let chosenFlavor = availableFlavors.randomElement() ?? .base

		switch chosenFlavor {
		case .base:
			return makeBaseGreeting(context: context, name: name)
		case .weather:
			return makeWeatherGreeting(context: context, name: name)
		case .mood:
			return makeMoodGreeting(context: context, name: name)
		}
	}

	// MARK: - 各类别生成函数

	private static func makeBaseGreeting(context: GreetingContext, name: String) -> String {
		let store = GreetingTemplateLoader.shared
		let templates = store.baseTemplates(for: context.timeSlot)
		let template = templates.randomElement() ?? "Welcome back, {name}!"
		return store.render(template, name: name)
	}

	private static func makeWeatherGreeting(context: GreetingContext, name: String) -> String {
		let store = GreetingTemplateLoader.shared
		if let weather = context.weather {
			let templates = store.weatherTemplates(for: weather)
			if let template = templates.randomElement() {
				return store.render(template, name: name)
			}
		}
		// 如果天气信息缺失或者模板为空，退回基础
		return makeBaseGreeting(context: context, name: name)
	}

	private static func makeMoodGreeting(context: GreetingContext, name: String) -> String {
		let store = GreetingTemplateLoader.shared
		guard let value = context.lastMood else {
			return makeBaseGreeting(context: context, name: name)
		}

		let level = MoodLevel.from(Double(value))
		let templates = store.moodTemplates(for: level)
		let template = templates.randomElement() ?? "Welcome back, {name}!"
		return store.render(template, name: name)
	}
}
