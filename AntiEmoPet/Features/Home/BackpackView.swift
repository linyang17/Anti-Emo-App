import SwiftUI

struct BackpackView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            Section("我的背包") {
                if appModel.inventory.isEmpty {
                    Text("空空如也，去商店购买一些物品吧！")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.inventory) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                HStack { Image(systemName: entry.type.icon); Text(entry.name) }
                                    .font(.headline)
                                Text("数量：\(entry.quantity)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("使用") {
                                appModel.useItem(sku: entry.sku)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(entry.quantity <= 0)
                        }
                    }
                }
            }
        }
        .navigationTitle("Backpack")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let energy = appModel.userStats?.totalEnergy {
                    Label("\(energy)", systemImage: "bolt")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

