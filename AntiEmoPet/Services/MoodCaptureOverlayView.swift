import SwiftUI

struct MoodCaptureOverlayView: View {
    let title: String
    @State private var value: Int
    let onSave: (Int) -> Void

    init(title: String = "How do you feel now?", initial: Int = 50, onSave: @escaping (Int) -> Void) {
        self.title = title
        // 确保初始值在有效范围内（10-100，step 10）
        let clamped = max(10, min(100, initial))
        let rounded = ((clamped / 10) * 10)  // 四舍五入到最近的10的倍数
        self._value = State(initialValue: rounded)
        self.onSave = onSave
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("10")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                        Text("\(value)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("100")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(value) },
                            set: { newValue in
                                // 确保值在 10-100 范围内，且是 10 的倍数
                                let clamped = max(10.0, min(100.0, newValue))
                                let rounded = round(clamped / 10.0) * 10.0
                                value = Int(rounded)
                            }
                        ),
                        in: 10...100,
                        step: 10
                    )
                }
                
                Button(action: {
                    onSave(value)
                }) {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            value >= 10 ? Color.blue : Color.gray,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .disabled(value < 10)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}
