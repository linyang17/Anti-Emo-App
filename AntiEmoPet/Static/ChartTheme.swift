import SwiftUI
import Combine

struct ChartTheme {
	static let shared = ChartTheme()

	// MARK: - Core Color Palette
	let sunny = [Color("#FFD166"), Color("#F77F00")]
	let cloudy = [Color("#9FA8DA"), Color("#5C6BC0")]
	let rainy  = [Color("#4FC3F7"), Color("#0288D1")]
	let snowy  = [Color("#E0F7FA"), Color("#80DEEA")]
	let windy  = [Color("#A7FFEB"), Color("#26A69A")]

	// MARK: - Gradient Factory
	func gradient(for type: WeatherType) -> LinearGradient {
		let colors: [Color]
		switch type {
		case .sunny:  colors = sunny
		case .cloudy: colors = cloudy
		case .rainy:  colors = rainy
		case .snowy:  colors = snowy
		case .windy:  colors = windy
		}
		return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
	}

	func glow(for type: WeatherType) -> Color {
		switch type {
		case .sunny:  return .orange
		case .cloudy: return .gray
		case .rainy:  return .cyan
		case .snowy:  return .white
		case .windy:  return .mint
		}
	}
}

struct ChartAnimation {
	static let barRise = Animation.spring(duration: 0.6, bounce: 0.15)
}
/// 通用图表动画，适用于任意符合 Identifiable & Equatable 的数据类型

final class AnimatedChartData<T: Identifiable & Equatable>: ObservableObject {
	@Published var displayData: [T] = []
	private var targetData: [T] = []
	private var animation: Animation
	private var cancellables = Set<AnyCancellable>()

	init(animation: Animation = .spring(duration: 0.6, bounce: 0.15)) {
		self.animation = animation
	}

	/// 设置目标数据并触发动画插值
	func update(with newData: [T]) {
		guard !newData.isEmpty else {
			displayData = []
			return
		}
		guard newData != targetData else { return }

		targetData = newData
		
		let start = zeroed(newData)

		withAnimation(animation) {
			displayData = start
		}

		// 上升动画（解锁真实数据）
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
			withAnimation(self.animation) {
				self.displayData = newData
			}
		}
	}

	
	func appear(with data: [T]) {
		update(with: data)
	}

	/// 自动生成一个“全零初始状态”
	private func zeroed(_ data: [T]) -> [T] {
		return data.map { item in
			if let mirror = Mirror(reflecting: item).children.first(where: { $0.value is Double }) {
				_ = item
				let mirrorValue = Mirror(reflecting: item)
				var dict = Dictionary(uniqueKeysWithValues: mirrorValue.children.map { ($0.label ?? "", $0.value) })
				if let label = mirror.label {
					dict[label] = 0.0
				}
				return item
			}
			return item
		}
	}
}
