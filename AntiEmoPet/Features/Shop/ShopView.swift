import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = ShopViewModel()
    @State private var alertMessage: String?

    var body: some View {
        List {
            ForEach(viewModel.grouped(items: appModel.shopItems)) { section in
                Section(section.type.rawValue.capitalized) {
                    ForEach(section.items) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text("消耗 \(item.costEnergy) 能量 · 心情 +\(item.moodBoost)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("购买") {
                                if !appModel.purchase(item: item) {
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
        .navigationTitle("Shop")
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
