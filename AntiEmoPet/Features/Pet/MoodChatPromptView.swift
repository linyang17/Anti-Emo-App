import SwiftUI

struct MoodChatPromptView: View {
        let onMaybeLater: () -> Void
        let onConfirm: () -> Void

        var body: some View {
                VStack(spacing: 24) {
                        Text("Wanna talk about it with Lumio?")
								.appFont(FontTheme.headline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)

                        HStack(spacing: 16) {
                                Button(action: onMaybeLater) {
                                        Text("Later")
                                                .appFont(FontTheme.subheadline)
                                                .foregroundStyle(.white.opacity(0.85))
                                                .padding(.horizontal, 22)
                                                .padding(.vertical, 10)
                                                .background(
                                                        Capsule(style: .continuous)
                                                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                                )
                                }
                                .buttonStyle(.plain)

                                Button(action: onConfirm) {
                                        Text("Sure")
                                                .appFont(FontTheme.subheadline)
                                                .foregroundStyle(.brown)
                                                .padding(.horizontal, 28)
                                                .padding(.vertical, 10)
                                                .background(
                                                        Capsule(style: .continuous)
                                                                .fill(Color.white)
                                                )
                                }
                                .buttonStyle(.plain)
                        }
                }
                .padding(22)
                .frame(maxWidth: .infinity)
				.background(FrostedCapsule(opacity: 0.8))
        }
}
