import SwiftUI

struct FontTheme {
	static let lineSpacing: CGFloat = 10
	static let letterSpacing: CGFloat = 0.5

	static func ABeeZee(_ size: CGFloat) -> Font {
		Font.custom("ABeeZee-Regular", size: size)
	}

	// 常用尺寸封装（可随时扩展）
	static var title: Font { ABeeZee(28) }
	static var title2: Font { ABeeZee(24) }
	static var title3: Font { ABeeZee(21) }
	static var headline: Font { ABeeZee(18) }
	static var body: Font { ABeeZee(16) }
	static var subheadline: Font { ABeeZee(14) }
	static var caption: Font { ABeeZee(12) }
}

extension View {
	func appFont(_ type: Font) -> some View {
		self.font(type)
			.lineSpacing(FontTheme.lineSpacing)
			.kerning(FontTheme.letterSpacing)
	}
	
	func appTextDefaults() -> some View {
		self
			.font(FontTheme.body)
			.lineSpacing(FontTheme.lineSpacing)
			.kerning(FontTheme.letterSpacing)
	}

	func appFontDefaults() -> some View {
		self
			.environment(\.font, FontTheme.body)
	}
}

extension Text {
	/// 统一应用：ABeeZee + lineSpacing + letterSpacing
	func appFont(_ font: Font) -> some View {
		self.font(font)
			.lineSpacing(FontTheme.lineSpacing)
			.kerning(FontTheme.letterSpacing)
	}

	/// 需要指定 size 的时候用这个
	func appFontSize(_ size: CGFloat) -> some View {
		self.appFont(FontTheme.ABeeZee(size))
	}
}

