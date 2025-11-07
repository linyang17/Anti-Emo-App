import SwiftUI

struct PetView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = PetViewModel()

    var body: some View {
        ScrollView {
            if let pet = appModel.pet {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image("PetCorgi")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: .orange.opacity(0.25), radius: 12, x: 0, y: 6)
                            // TODO(中/EN): Replace with animated 3D pet once art team ships sprites; keep corgi.webp placeholder 🐶.
                        Text(pet.name)
                            .font(.largeTitle.bold())
                        Text(viewModel.moodDescription(for: pet))
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

                    PrimaryButton(title: "摸摸 Sunny 🐾") {
                        appModel.petting()
                    }

                    if let snack = appModel.shopItems.first(where: { $0.type == .snack }) {
                        PrimaryButton(title: "喂零食：\(snack.name) 🍪") {
                            _ = appModel.purchase(item: snack)
                        }
                    } else {
                        Text("🍪 还没有可用的零食，先去商店补货吧")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            // TODO(中/EN): Replace with inventory carousel once store module ships multiple SKUs.
                    }
                }
                .padding()
            } else {
                Text("尚未创建宠物 · Tap onboarding first")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Pet")
    }
}
