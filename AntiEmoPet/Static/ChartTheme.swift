import SwiftUI
import Combine

struct ChartTheme {
	static let shared = ChartTheme()

	// MARK: - Core Color Palette
	let grad_orange = [Color(hex: "#FFD166"), Color(hex: "#F77F00")]
	let grad_gray   = [Color(hex: "#D2D2D2"), Color(hex: "#848484")]
	let grad_cyan   = [Color(hex: "#90DDFF"), Color(hex: "#0288D1")]
	let grad_white  = [Color(hex: "#EFF3F6"), Color(hex: "#E0F7FA")]
	let grad_mint   = [Color(hex: "#A7FFEB"), Color(hex: "#26A69A")]
	let grad_purple = [Color(hex: "#DBB0E2"), Color(hex: "#8E24AA")]
	let grad_red    = [Color(hex: "#FF8A80"), Color(hex: "#E53935")]
	let grad_green  = [Color(hex: "#A5D6A7"), Color(hex: "#388E3C")]
	let grad_pink   = [Color(hex: "#FFD3EF"), Color(hex: "#FF98DA")]

	// MARK: - Universal Gradient Factory
	func gradient<T>(for type: T) -> LinearGradient {
		switch type {
		case let weather as WeatherType:
			return gradient(for: weather)
		case let task as TaskCategory:
			return gradient(for: task)
		default:
			return LinearGradient(colors: grad_gray, startPoint: .top, endPoint: .bottom)
		}
	}

	// MARK: - WeatherType Gradients
	func gradient(for type: WeatherType) -> LinearGradient {
		let colors: [Color]
		switch type {
		case .sunny:  colors = grad_orange
		case .cloudy: colors = grad_gray
		case .rainy:  colors = grad_cyan
		case .snowy:  colors = grad_white
		case .windy:  colors = grad_mint
		}
		return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
	}

	// MARK: - TaskCategory Gradients
	func gradient(for type: TaskCategory) -> LinearGradient {
		let colors: [Color]
		switch type {
		case .indoorActivity: colors = grad_green
		case .indoorDigital: colors = grad_gray
		case .socials: colors = grad_pink
		case .outdoor: colors = grad_orange
		case .physical: colors = grad_red
		case .petCare: colors = grad_cyan
		}
		return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
	}

	// MARK: - Universal Glow
	func glow<T>(for type: T) -> Color {
		switch type {
		case let weather as WeatherType:
			return glow(for: weather)
		case let task as TaskCategory:
			return glow(for: task)
		default:
			return .gray
		}
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

	func glow(for type: TaskCategory) -> Color {
		switch type {
		case .indoorActivity: return .green
		case .indoorDigital: return .gray
		case .socials: return .pink
		case .outdoor: return .orange
		case .physical: return .red
		case .petCare: return .cyan
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

extension Color {
	init(hex: String) {
		let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		var int: UInt64 = 0
		Scanner(string: hex).scanHexInt64(&int)
		let a, r, g, b: UInt64
		switch hex.count {
		case 3: // RGB (12-bit)
			(a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
		case 6: // RGB (24-bit)
			(a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
		case 8: // ARGB (32-bit)
			(a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
		default:
			(a, r, g, b) = (255, 0, 0, 0)
		}

		self.init(
			.sRGB,
			red: Double(r) / 255,
			green: Double(g) / 255,
			blue: Double(b) / 255,
			opacity: Double(a) / 255
		)
	}
}
