import SwiftUI

struct PetView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = PetViewModel()

    var body: some View {
        ScrollView {
            if let pet = appModel.pet {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 120))
                            .foregroundStyle(.orange)
                        Text(pet.name)
                            .font(.largeTitle.bold())
                        Text(viewModel.moodDescription(for: pet))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("心情", systemImage: "sparkles")
                        ProgressView(value: Double(pet.level) / 10.0)
                            .tint(.yellow)
                        Label("饱食度", systemImage: "fork.knife")
                        ProgressView(value: Double(pet.hunger) / 100.0)
                            .tint(.pink)
                        Label("等级", systemImage: "chart.bar")
                        Text("Lv. \(pet.level)  · XP \(pet.xp)/100")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.1)))

                    PrimaryButton(title: "摸摸 Sunny") {
                        appModel.petting()
                    }

                    if let snack = appModel.shopItems.first(where: { $0.type == .snack }) {
                        PrimaryButton(title: "喂零食：\(snack.name)") {
                            _ = appModel.purchase(item: snack)
                        }
                    }
                }
                .padding()
            } else {
                Text("尚未创建宠物")
            }
        }
        .navigationTitle("Pet")
    }
}
