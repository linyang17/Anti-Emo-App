import Foundation

/// 通用趋势方向枚举，既用于情绪统计也用于能量统计。
/// 使用 SF Symbol 名称作为 rawValue，方便直接在视图中展示箭头图标。
enum TrendDirection: String, Codable, Sendable {
        case up = "arrow.up.right"
        case down = "arrow.down.right"
        case flat = "arrow.right"

        /// A unicode arrow that mirrors the SF Symbol for quick inline usage.
        var textualArrow: String {
                switch self {
                case .up: "↑"
                case .down: "↓"
                case .flat: "→"
                }
        }

        /// Accessible description that can be surfaced by assistive technologies.
        var accessibilityLabel: String {
                switch self {
                case .up: "趋势上升"
                case .down: "趋势下降"
                case .flat: "趋势持平"
                }
        }
}
