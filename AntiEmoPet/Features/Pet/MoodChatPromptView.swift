import SwiftUI

struct MoodChatPromptView: View {
        let onMaybeLater: () -> Void
        let onConfirm: () -> Void

        var body: some View {
                VStack(spacing: 18) {
                        Spacer().frame(height: 4)
                        Text("Wanna talk about it more?")
                                .appFont(FontTheme.title3)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)

                        HStack(spacing: 16) {
                                Button(action: onMaybeLater) {
                                        Text("Maybe later")
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
                                        Text("Ok")
                                                .appFont(FontTheme.subheadline)
                                                .foregroundStyle(.black)
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
                .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                        LinearGradient(colors: [Color(red: 0.17, green: 0.42, blue: 0.2), Color(red: 0.12, green: 0.29, blue: 0.18)], startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                )
        }
}
