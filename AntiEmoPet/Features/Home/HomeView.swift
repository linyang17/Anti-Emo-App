import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DashboardCard(title: "今日天气", icon: appModel.weather.icon) {
                    Text(appModel.weather.title)
                        .font(.largeTitle.bold())
                    Text(viewModel.tip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // TODO(中/EN): Swap mock weather with WeatherKit feed + location consent (PRD §3 WeatherService).
                }

                DashboardCard(title: "任务进度", icon: "checkmark.circle") {
                    ProgressView(value: appModel.completionRate)
                        .tint(.green)
                    Text("完成率 \(Int(appModel.completionRate * 100))%")
                        .font(.title3.bold())
                    // TODO(中/EN): Add streak badge + reward CTA per gamification spec once animation assets ready.
                }

                if let pet = appModel.pet {
                    DashboardCard(title: "Sunny 状态", icon: "pawprint") {
                        Text("心情：\(pet.mood.displayName)")
                        Text("饱食度：\(pet.hunger)%")
                        Text("Level \(pet.level) · XP \(pet.xp)/100")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    PrimaryButton(title: "摸摸 Sunny") {
                        appModel.petting()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .onAppear {
            viewModel.updateTip(weather: appModel.weather)
        }
        .onChange(of: appModel.weather) { newValue in
            viewModel.updateTip(weather: newValue)
        }
    }
}
