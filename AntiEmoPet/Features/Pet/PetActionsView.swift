import SwiftUI

struct FoxWaveStepView: View {
	@EnvironmentObject private var appModel: AppViewModel
	let onTap: () -> Void

	@ViewBuilder
	private var welcomeText: some View {
		if appModel.userStats?.Onboard == true {
			LumioSay(text: "Welcome back,\n \(appModel.userStats?.nickname ?? "my friend")!")
		} else {
			LumioSay(text: "Now we know each other.\n Our Journey has just begun!")
		}
	}

	var body: some View {
		ZStack {
			Image("bg-main")
				.resizable()
				.scaledToFill()
				.ignoresSafeArea()
			
			VStack {
					welcomeText
						.transition(.opacity)
						.frame(maxWidth: .infinity)
						.padding(.top, 120)
						.padding(.bottom, 120)

					Spacer(minLength: 50)
				}
			
			VStack {
				Image("foxwave")
					.resizable()
					.scaledToFit()
					.frame(maxWidth: 220)
					.padding(.top, 20)
					.padding(.bottom, 20)
			}
			// TODO: 改成 Lottie 动画
		}
		.contentShape(Rectangle()) // 整屏可点击
		.onTapGesture {
			onTap()
		}
	}
}
