import Foundation

/// 通用趋势方向枚举，既用于情绪统计也用于能量统计。
/// 使用 SF Symbol 名称作为 rawValue，方便直接在视图中展示箭头图标。
enum TrendDirection: String, Codable, Sendable {
        case up = "arrow.up.right"
        case down = "arrow.down.right"
        case flat = "arrow.right"
}
