import SwiftUI

struct PetView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = PetViewModel()
    @StateObject private var weatherVM = HomeViewModel()

    var body: some View {
        ScrollView {
            if let pet = appModel.pet {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image("foxlooking")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: .orange.opacity(0.25), radius: 12, x: 0, y: 6)
                            // TODO(中/EN): Replace with animated 3D pet once art team ships sprites; keep corgi.jpeg placeholder 🐶.
                        Text(pet.name)
                            .font(.largeTitle.bold())
                        Text(viewModel.moodDescription(for: pet))
                            .foregroundStyle(.secondary)
                    }

                    DashboardCard(title: "现在天气", icon: appModel.weather.icon) {
                        Text(appModel.weather.title)
                            .font(.title.bold())
                        Text(weatherVM.tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }


                    VStack(alignment: .leading, spacing: 12) {
                        Label("心情 Mood", systemImage: "sparkles")
                        ProgressView(value: Double(pet.level) / 10.0) {
                            Text("🥳") // Emoji placeholder for mood meter per MVP visuals.
                        }
                        .tint(.yellow)
                        Label("饱食度 Hunger", systemImage: "fork.knife")
                        ProgressView(value: Double(pet.hunger) / 100.0) {
                            Text("🍖")
                        }
                        .tint(.pink)
                        Label("等级 Level", systemImage: "chart.bar")
                        Text("Lv. \(pet.level)  · XP \(pet.xp)/100")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.1)))
                    // TODO(中/EN): Hook up to live animation + weather-reactive stats from PRD section 3 once data available.

                    PrimaryButton(title: "摸摸 Lumio 🐾") {
                        appModel.petting()
                    }

                    HStack(spacing: 12) {
                        NavigationLink(destination: BackpackView().environmentObject(appModel)) {
                            Label("打开背包", systemImage: "bag")
                        }
                        if let snack = appModel.shopItems.first(where: { $0.type == .snack }),
                           appModel.inventory.first(where: { $0.sku == snack.sku && $0.count > 0 }) != nil {
                            PrimaryButton(title: "喂零食：\(snack.name) 🍪") {
                                appModel.useItem(sku: snack.sku)
                            }
                        } else {
                            Text("🍪 背包没有零食，先去商店购买吧")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            } else {
                Text("尚未创建宠物 · Tap onboarding first")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Pet")
        .energyToolbar(appModel: appModel)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: BackpackView().environmentObject(appModel)) {
                    Image(systemName: "bag")
                }
            }
        }
        .onAppear {
            weatherVM.updateTip(weather: appModel.weather)
        }
        .onChange(of: appModel.weather) { newValue in
            weatherVM.updateTip(weather: newValue)
        }
    }
}
