import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = HomeViewModel()
    @State private var saveToast: (String, Date)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                DashboardCard(title: "今日天气详情", icon: appModel.weather.icon) {
                    Text(appModel.weather.title)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                    Text(viewModel.tip)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("当前情绪", systemImage: "face.smiling")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("0")
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { Double(viewModel.moodValue) },
                            set: { viewModel.moodValue = Int($0) }
                        ), in: 0...100, step: 1)
                        Text("100")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("当前：\(viewModel.moodValue)")
                        Spacer()
                        Button("保存") {
                            appModel.addMoodEntry(value: viewModel.moodValue)
                            saveToast = ("已保存", .now)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                if case let (_, t)? = saveToast, Date().timeIntervalSince(t) > 1.0 {
                                    saveToast = nil
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Label("体感建议", systemImage: "figure.walk")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(suggestionText(for: appModel.weather))
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding()
            .overlay(alignment: .top) {
                if let energy = appModel.userStats?.totalEnergy {
                    EmptyView()
                }
            }
        }
        .overlay(alignment: .top) {
            if let toast = saveToast {
                Text(toast.0)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: saveToast != nil)
        .energyToolbar(appModel: appModel)
        .navigationTitle("Weather")
        .onAppear {
            viewModel.updateTip(weather: appModel.weather)
            viewModel.loadLatestMood(from: appModel)
        }
        .onChange(of: appModel.weather) { newValue in
            viewModel.updateTip(weather: newValue)
        }
    }

    private func suggestionText(for weather: WeatherType) -> String {
        switch weather {
        case .sunny:
            return "阳光明媚，适合户外运动和补充维生素 D。"
        case .cloudy:
            return "现在多云，出门散步或者做些轻运动很不错。"
        case .rainy:
            return "雨天适合室内冥想、阅读或热饮放松。"
        case .snowy:
            return "注意保暖，可选择室内伸展或短时户外活动。"
        case .windy:
            return "风大时注意防风，优先安排室内活动。"
        }
    }
}
