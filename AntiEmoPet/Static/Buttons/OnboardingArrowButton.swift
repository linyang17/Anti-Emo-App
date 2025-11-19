import SwiftUI

struct LumioSay: View {
        let text: String
        private static let maxBubbleWidth: CGFloat = {
                let characters = String(repeating: "W", count: 20)
                let preferredSize = UIFontMetrics.default.scaledValue(for: 16)
                let font = UIFont.monospacedSystemFont(ofSize: preferredSize, weight: .regular)
                let size = (characters as NSString).size(withAttributes: [.font: font])
                return size.width
        }()

        var body: some View {
                Text(text)
                        .font(.system(size: 21, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .shadow(color: .gray.opacity(0.25), radius: 4, x: 1, y: 1)
                        .shadow(color: .cyan.opacity(0.1), radius: 2, x: 1, y: 1)
                        .frame(maxWidth: LumioSay.maxBubbleWidth)
	}
}


struct OnboardingArrowButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                circleFill

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .semibold))
						.foregroundStyle(Color.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
		.frame(width: 44, height: 44)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .accessibilityLabel("下一步")
    }

	private var circleFill: some View {
		ZStack {
			// 背景磨砂玻璃
			Circle()
				.fill(.ultraThinMaterial)
				.blur(radius: 0.5)
				.opacity(isEnabled ? 0.7 : 0.4)
				.overlay(
					AngularGradient(
						gradient: Gradient(colors: [
							.white.opacity(0.12),
							.clear,
							.gray.opacity(0.12),
							.clear,
							.purple.opacity(0.1)
						]),
						center: .center
					)
					.blendMode(.plusLighter)
					.blur(radius: 4)
				)
				.shadow(color: glowColor.opacity(isEnabled && !isLoading ? 0.5 : 0.1),
						radius: isEnabled && !isLoading ? 12 : 3,
						x: 0, y: 4)

			Circle()
				.fill(
					LinearGradient(
						colors: isEnabled && !isLoading
						? [Color.white.opacity(0.5), Color.white.opacity(0.15)]
						: [Color.white.opacity(0.25), Color.white.opacity(0.08)],
						startPoint: .top,
						endPoint: .bottom
					)
				)
				.opacity(isEnabled ? 0.7 : 0.4)
				.blendMode(.softLight)
		}
	}
	
	private var glowColor: Color {
		if isEnabled && !isLoading {
			return Color.purple.opacity(0.2)
		} else {
			return Color.gray.opacity(0.2)
		}
	}
}
