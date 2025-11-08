import SwiftUI

struct MoodCaptureOverlayView: View {
    let title: String
    @State private var value: Int
    let onSave: (Int) -> Void

    init(title: String = "记录一下现在的心情", initial: Int = 5, onSave: @escaping (Int) -> Void) {
        self.title = title
        self._value = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.headline)
            HStack {
                Text("0").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(value) }, set: { value = Int($0) }), in: 0...100, step: 1)
                Text("100").foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("保存") { onSave(value) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}
