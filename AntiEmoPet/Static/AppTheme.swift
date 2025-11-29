// MARK: - Global Text & Glass Styles

import SwiftUI


enum AppTheme {
    /// 全局主文字颜色
    static let primaryText = Color("#6B2929")
}

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                // 超薄材料 + 轻微着色
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        // 内部透明度渐变：上方略亮、下方略深
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blendMode(.softLight)
                        .clipShape(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                    )
            )
            .overlay(
                // 外框高光描边，增加玻璃边缘感
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        Color.white.opacity(0.35),
                        lineWidth: 1
                    )
                    .shadow(color: Color.white.opacity(0.18), radius: 4, x: 0, y: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
    }
}

extension View {
    /// 统一应用玻璃磨砂 + 内部渐变效果，方便循环使用
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 16) -> some View {
        self.modifier(GlassCardStyle(cornerRadius: cornerRadius, padding: padding))
    }

    /// 统一主文字颜色（由原来的白色改为 6B2929）
    func appPrimaryText() -> some View {
        self.foregroundStyle(AppTheme.primaryText)
    }
}

// MARK: Offset
extension CGFloat {
	static func w(_ proportion: CGFloat) -> CGFloat {
		UIScreen.main.bounds.width * proportion // 按 iPhone 17 Pro 宽度比例
	}
	static func h(_ proportion: CGFloat) -> CGFloat {
		UIScreen.main.bounds.height * proportion // 按 iPhone 17 Pro 高度比例
	}
}
