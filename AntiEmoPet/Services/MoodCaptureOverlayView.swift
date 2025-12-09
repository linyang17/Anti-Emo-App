import SwiftUI

struct MoodCaptureOverlayView: View {
	// MARK: - Constants
	private enum Constants {
		static let minValue = 10.0
		static let maxValue = 100.0
		static let step = 10.0
	}

	// MARK: - Properties
	@State private var value: Int? = nil
	let onSave: (Int) -> Void

        // MARK: - Body
        var body: some View {
                VStack(spacing: 24) {
                        Text("How do you feel now?")
                                .appFont(FontTheme.headline)
                                .foregroundStyle(.white)

                        VStack(spacing: 12) {
                                HStack {
                                        Text("10")
                                                .foregroundStyle(.white.opacity(0.7))
                                                .appFont(FontTheme.body)
                                        Spacer()
                                        Text("100")
                                                .foregroundStyle(.white.opacity(0.7))
                                                .appFont(FontTheme.body)
                                }

                                Slider(
                                        value: Binding(
                                                get: { Double(value ?? 55) },
                                                set: { newValue in
                                                        let clamped = max(Constants.minValue, min(Constants.maxValue, newValue))
                                                        let rounded = round(clamped / Constants.step) * Constants.step
                                                        value = Int(rounded)
                                                }
                                        ),
                                        in: Constants.minValue...Constants.maxValue,
                                        step: Constants.step
                                )
                                .tint(.white)
                        }

                        Button(action: {
                                if let value = value {
                                        onSave(value)
                                }
                        }) {
                                Text("Save")
                                        .appFont(FontTheme.subheadline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                                LinearGradient(
                                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.7)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                ),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        )
                        }
                        .disabled(value == nil)
                        .opacity(value == nil ? 0.7 : 1)
                }
                .padding(26)
                .background(glassSurface)
                .padding(32)
        }

        private var glassSurface: some View {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                                LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                )
                        )
                        .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 16)
        }
}
