import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = ShopViewModel()
    @State private var alertMessage: String?
    @State private var purchaseToast: (String, Date)? = nil

    var body: some View {
        List {
            ForEach(viewModel.grouped(items: appModel.shopItems)) { section in
                Section(section.type.rawValue.capitalized) {
                    ForEach(section.items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text("已有数量：\(appModel.inventory.first(where: { $0.sku == item.sku })?.count ?? 0)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("消耗 \(item.costEnergy) 能量 · 心情 +\(item.moodBoost) ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                // TODO(中/EN): Display coin/energy split pricing + rarity tiers (PRD 商店模块).
                            }
                            Spacer()
                            Button("购买") {
                                if appModel.purchase(item: item) {
                                    alertMessage = "已购买：\(item.name)\n心情 +\(item.moodBoost) · 饱食度 +\(item.hungerBoost)\n消耗能量 \(item.costEnergy)"
                                    purchaseToast = ("能量 -\(item.costEnergy)", .now)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        if case let (_, timestamp)? = purchaseToast, Date().timeIntervalSince(timestamp) > 1.0 {
                                            purchaseToast = nil
                                        }
                                    }
                                } else {
                                    alertMessage = "能量不足，完成任务可获得能量哦"
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .top) {
            if let toast = purchaseToast {
                Text(toast.0)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: purchaseToast != nil)
        .navigationTitle("Shop")
        .toolbar {
            NavigationLink(destination: BackpackView()) {
                Label("背包", systemImage: "bag")
            }
        }
        .energyToolbar(appModel: appModel)
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }
}
