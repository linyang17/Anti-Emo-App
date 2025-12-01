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
                ZStack {

					VStack(spacing: 24) {
						Text("How do you feel now?")
								.font(.headline)
								.foregroundStyle(.primary)

						VStack(spacing: 12) {
								HStack {
										Text("10")
												.foregroundStyle(.secondary)
												.font(.body)
										Spacer()
										Text("100")
												.foregroundStyle(.secondary)
												.font(.body)
								}

								Slider(
									value: Binding(
										get: { Double(value ?? 55) }, // midpoint visual start
										set: { newValue in
												let clamped = max(Constants.minValue, min(Constants.maxValue, newValue))
												let rounded = round(clamped / Constants.step) * Constants.step
												value = Int(rounded)
											}
										),
									in: Constants.minValue...Constants.maxValue,
									step: Constants.step
								)
                                }

                                Button(action: {
									if let value = value {
											onSave(value)
									}
                                }) {
									Text("Save")
										.font(.headline)
										.foregroundStyle(.white)
										.frame(maxWidth: .infinity)
										.padding(.vertical, 12)
										.background(
												value != nil ? Color.blue : Color.gray,
												in: RoundedRectangle(cornerRadius: 12)
										)
                                }
                                .disabled(value == nil)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .padding(32)
                }
        }
}
