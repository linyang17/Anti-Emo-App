import SwiftUI

struct MoodCaptureOverlayView: View {
	private enum Constants {
		static let minValue = 10.0
		static let maxValue = 100.0
		static let step = 10.0
	}

	let title: String
	let source: MoodEntry.Source
	@State private var value: Double
	let onSave: (Int, MoodEntry.Source) -> Void

	init(
		title: String = "How do you feel now?",
		source: MoodEntry.Source = .appOpen,
		initial: Int = 50,
		onSave: @escaping (Int, MoodEntry.Source) -> Void
	) {
		self.title = title
		self.source = source
		let clamped = min(max(Double(initial), Constants.minValue), Constants.maxValue)
		self._value = State(initialValue: clamped)
		self.onSave = onSave
	}

	var body: some View {
		VStack(spacing: 20) {
			Text(title)
				.font(.title3.weight(.semibold))
				.multilineTextAlignment(.center)

			Text("\(Int(value))")
				.font(.system(size: 48, weight: .bold, design: .rounded))
				.foregroundStyle(.primary)

			HStack {
				Text("\(Int(Constants.minValue))").foregroundStyle(.secondary)
				Slider(
					value: Binding(
						get: { value },
						set: { value = round($0 / Constants.step) * Constants.step }
					),
					in: Constants.minValue...Constants.maxValue,
					step: Constants.step
				)
				Text("\(Int(Constants.maxValue))").foregroundStyle(.secondary)
			}

			Button {
				onSave(Int(value), source)
			} label: {
				Text("保存")
					.font(.headline)
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.padding(.top, 8)
		}
		.padding(24)
		.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
		.shadow(radius: 16)
		.padding(24)
	}
}
