import SwiftUI
import UIKit


struct PrimaryButton: View {
	let title: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Text(title)
				.fontWeight(.semibold)
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.accentColor)
				.foregroundStyle(.white)
				.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
		}
	}
}


struct FrostedCapsule: View {
	var opacity: Double = 0.75
	private let radius: CGFloat = 22

	var body: some View {
		RoundedRectangle(cornerRadius: radius, style: .continuous)
			.fill(.ultraThinMaterial)
			.overlay(
				RoundedRectangle(cornerRadius: radius, style: .continuous)
					.fill(
						LinearGradient(
							colors: [Color.white.opacity(0.28), Color.white.opacity(0.12)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
			)
			.overlay(
				RoundedRectangle(cornerRadius: radius, style: .continuous)
					.stroke(Color.white.opacity(0.2), lineWidth: 1)
			)
			.shadow(color: .white.opacity(0.2), radius: 4, x: -1, y: -1)
			.shadow(color: .purple.opacity(0.2), radius: 8, x: 1, y: 2)
			.opacity(opacity)
	}
}


struct FrostedCircle: View {
	var opacity: Double = 1.0

	var body: some View {
		Circle()
			.fill(.ultraThinMaterial)
			.overlay(
				Circle()
					.fill(
						LinearGradient(
							colors: [Color.white.opacity(0.35), Color.white.opacity(0.15)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
			)
			.overlay(
				Circle()
					.stroke(Color.white.opacity(0.25), lineWidth: 1)
			)
			.shadow(color: .white.opacity(0.2), radius: 4, x: -1, y: -1)
			.shadow(color: .purple.opacity(0.2), radius: 8, x: 1, y: 2)
			.opacity(opacity)
	}
}
