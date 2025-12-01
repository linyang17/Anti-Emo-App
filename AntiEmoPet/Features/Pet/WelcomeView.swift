import SwiftUI

struct WelcomeView: View {
	@EnvironmentObject private var appModel: AppViewModel
	let onTap: () -> Void
	@State private var greeting: String = ""
	@State private var mood: MoodStatisticsViewModel.MoodSummary = .empty

	@ViewBuilder
	private var welcomeText: some View {
		if appModel.userStats?.Onboard == true {
			LumioSay(text: greeting)
		} else {
			LumioSay(text: "Now we know each other.\n Our Journey has begun!")
		}
	}
	
	private func buildGreeting() -> String {
		let username = appModel.userStats?.nickname ?? ""
		let name = username.isEmpty ? "my friend" : username

		let calendar = TimeZoneManager.shared.calendar
		let slot = TimeSlot.from(date: Date(), using: calendar)
		let weather: WeatherType = appModel.weather
		let lastMood = mood.lastMood

		let context = GreetingContext(
			name: name,
			timeSlot: slot,
			weather: weather,
			lastMood: lastMood
		)
		
		return GreetingEngine.makeGreeting(from: context)
	}
	

	var body: some View {
		ZStack {
			Image("bg-main")
				.resizable()
				.scaledToFill()
				.ignoresSafeArea()
			
                        VStack {
								welcomeText
										.frame(maxWidth: .w(0.7), alignment: .leading)
										.padding(.top, .h(0.18))
										.padding(.bottom, .h(0.14))

							Spacer(minLength: 0.1)
							}
			
                        VStack {
                                Image("foxwave")
                                        .resizable()
                                        .scaledToFit()
										.frame(maxWidth: .w(0.5), maxHeight: .h(0.25))
										.padding(.top, .h(0.2))
                        }
			// TODO: 改成 Lottie 动画
		}
		.contentShape(Rectangle()) // 整屏可点击
		.onAppear {
			greeting = buildGreeting()
		}
		.onTapGesture {
			onTap()
		}
	}
}

