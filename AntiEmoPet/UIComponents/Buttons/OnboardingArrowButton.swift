import SwiftUI

struct OnboardingArrowButton: View {
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(circleFill)
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.accentColor)
                } else {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 72, height: 72)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .accessibilityLabel("下一步")
    }

    private var circleFill: LinearGradient {
        if isEnabled && !isLoading {
            return LinearGradient(
                colors: [Color.white.opacity(0.95), Color.white.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.6), Color.white.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
