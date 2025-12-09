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
                VStack(spacing: 18) {
                        Text("How do you feel now?")
							.appFont(FontTheme.headline)
								.bold()
                                .foregroundStyle(.white)

                        VStack(spacing: 4) {
                                HStack {
                                        Text("10")
												.appFont(FontTheme.subheadline)
                                                .foregroundStyle(.white)
                                        Spacer()
                                        Text("100")
												.appFont(FontTheme.subheadline)
                                                .foregroundStyle(.white)
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
									.bold()
									.foregroundStyle(.white)
									.frame(maxWidth: .w(0.5))
									.padding(.vertical, 8)
									.background(
											LinearGradient(
												colors: [Color.indigo.opacity(0.8), Color.pink.opacity(0.7)],
													startPoint: .leading,
													endPoint: .trailing
											),
											in: RoundedRectangle(cornerRadius: 14, style: .continuous)
									)
                        }
                        .disabled(value == nil)
                        .opacity(value == nil ? 0.7 : 1)
                }
                .padding(24)
				.background(FrostedCapsule(opacity: 0.95))
				.frame(maxWidth: .w(0.7))
        }
}
