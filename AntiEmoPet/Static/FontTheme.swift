import SwiftUI

struct FontTheme {

    static func ABeeZee(_ size: CGFloat) -> Font {
        Font.custom("ABeeZee", size: size)
    }

    // 常用尺寸封装（可随时扩展）
    static var title: Font { ABeeZee(28) }
    static var title2: Font { ABeeZee(22) }
    static var headline: Font { ABeeZee(18) }
    static var body: Font { ABeeZee(16) }
    static var subheadline: Font { ABeeZee(14) }
    static var caption: Font { ABeeZee(12) }
}

extension View {
	func appFont(_ type: Font) -> some View {
		self.font(type)
	}

	func appFontSize(_ size: CGFloat) -> some View {
		self.font(FontTheme.ABeeZee(size))
	}
}
