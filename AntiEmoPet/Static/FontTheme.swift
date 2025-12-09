import SwiftUI
import UIKit
import OSLog


struct FontTheme {
	struct ThemedFont {
		let font: Font
		let size: CGFloat
	}

	static let letterSpacing: CGFloat = 0.25

	// MARK: - 字体加载器
	static func ABeeZee(_ size: CGFloat) -> ThemedFont {
		ThemedFont(font: .custom("ABeeZee-Regular", size: size), size: size)
	}

	// MARK: - 常用字号封装（附带字号信息）
	static let title       = ABeeZee(28)
	static let title2      = ABeeZee(24)
	static let title3      = ABeeZee(21)
	static let headline    = ABeeZee(18)
	static let subheadline = ABeeZee(16)
	static let body		   = ABeeZee(14)
	static let caption     = ABeeZee(12)
	static let footnote    = ABeeZee(10)
}

// MARK: - View 扩展（自动计算行距）
extension View {
	func appFont(_ themed: FontTheme.ThemedFont) -> some View {
		self.font(themed.font)
			.lineSpacing(themed.size * 2 / 3)
			.kerning(FontTheme.letterSpacing)
	}

	func appFontDefaults() -> some View {
		self.environment(\.font, FontTheme.body.font)
	}
}

// MARK: - Text 扩展（更简洁调用）
extension Text {
	func appFont(_ themed: FontTheme.ThemedFont) -> some View {
		self.font(themed.font)
			.lineSpacing(themed.size * 2 / 3)
			.kerning(FontTheme.letterSpacing)
	}

	func appFontSize(_ size: CGFloat) -> some View {
		self.appFont(FontTheme.ABeeZee(size))
	}
}


extension UIAppearance {
        static func setupGlobalFonts() {
                let logger = Logger(subsystem: "com.Lumio.pet", category: "FontTheme")
                guard let abeezee16 = UIFont(name: "ABeeZee-Regular", size: 16) else {
                        logger.error("Failed to load ABeeZee-Regular font.")
                        return
                }

                let titleFont = UIFont(name: "ABeeZee-Regular", size: 24) ?? abeezee16
                let largeTitleFont = UIFont(name: "ABeeZee-Regular", size: 32) ?? abeezee16

                UINavigationBar.appearance().titleTextAttributes = [
                        .font: titleFont
                ]

                UINavigationBar.appearance().largeTitleTextAttributes = [
                        .font: largeTitleFont
                ]

                UIBarButtonItem.appearance().setTitleTextAttributes([
                        .font: UIFont(name: "ABeeZee-Regular", size: 16)!
                ], for: .normal)

		UITextField.appearance().defaultTextAttributes = [
			.font: abeezee16
		]

		UILabel.appearance().font = abeezee16
	}
}
