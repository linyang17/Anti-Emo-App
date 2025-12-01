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
                                                .frame(maxWidth: .infinity, alignment: .center)
                                                .padding(.top, 150)
                                                .padding(.bottom, 120)

					Spacer(minLength: 50)
				}
			
                        VStack {
                                Image("foxwave")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: 220, maxHeight: 220)
                                        .padding(.top, 20)
                                        .padding(.bottom, 20)
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

