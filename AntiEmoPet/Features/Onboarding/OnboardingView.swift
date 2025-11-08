import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 72))
                .foregroundStyle(.yellow)
                // TODO(中/EN): Replace icon with illustrated mascot per PRD onboarding storyboard.
            Text("欢迎来到 SunnyPet")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text("分享你的昵称和所在地区，Sunny 将结合天气为你推荐任务。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                TextField("昵称", text: $viewModel.nickname)
                    .textFieldStyle(.roundedBorder)
                TextField("所在城市", text: $viewModel.region)
                    .textFieldStyle(.roundedBorder)
                Toggle("接收每日提醒", isOn: $viewModel.notificationsOptIn)
            }

            PrimaryButton(title: "进入 SunnyPet") {
                guard viewModel.canSubmit else { return }
                appModel.updateProfile(
                    nickname: viewModel.nickname,
                    region: viewModel.region
                )
                if viewModel.notificationsOptIn {
                    appModel.requestNotifications()
                }
            }
            .disabled(!viewModel.canSubmit)
            Spacer()
        }
        .padding()
        // TODO(中/EN): Stage 2 of onboarding should ask for mood baseline + daylight sensitivity (PRD §4).
    }
}
