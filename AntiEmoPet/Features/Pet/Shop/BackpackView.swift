import SwiftUI

struct BackpackView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        List {
            Section("背包") {
                if appModel.inventory.isEmpty {
                    Text("空空如也，去商店购买一些物品吧！")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.inventory) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                if let item = appModel.shopItems.first(where: { $0.sku == entry.sku }) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text(item.type.rawValue.capitalized)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(entry.sku)
                                        .font(.headline)
                                }
                                Text("数量：\(entry.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("使用") {
                                appModel.useItem(sku: entry.sku)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(entry.count <= 0)
                        }
                    }
                }
            }
        }
        .navigationTitle("Backpack")
    }
}

