import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = ShopViewModel()
    @State private var alertMessage: String?
    @State private var purchaseToast: (String, Date)?

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                ForEach(viewModel.grouped(items: appModel.shopItems)) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(shopSections(for: section.type), systemImage: section.type.icon)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(section.items) { item in
                                shopCard(for: item)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) { toastView }
        .animation(.spring(duration: 0.3), value: purchaseToast != nil)
        .navigationTitle("商店")
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { _ in alertMessage = nil }
        )) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                statusBadge(value: "\(appModel.userStats?.totalEnergy ?? 0)", icon: "bolt.fill")
                statusBadge(value: "\(appModel.userStats?.coins ?? 0)", icon: "cookie.fill")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shopCard(for item: Item) -> some View {
        let ownedCount = appModel.inventory.first(where: { $0.sku == item.sku })?.count ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text("x \(ownedCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(item.costEnergy) ⚡️")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            Text("关系 +\(item.BondingBoost) · 饱食 +\(item.hungerBoost)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button {
                handlePurchase(item)
            } label: {
                Text("兑换")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 160)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statusBadge(value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                Text(value)
                    .font(.body.weight(.semibold))
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = purchaseToast {
            Text(toast.0)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func shopSections(for type: ItemType) -> String {
        switch type {
        case .snack:
            return "食物"
        case .toy:
            return "头部"
        case .decor:
            return "衣服"
        }
    }

    private func handlePurchase(_ item: Item) {
        if appModel.purchase(item: item) {
            alertMessage = "已兑换：\(item.name)\n关系 +\(item.BondingBoost) · 饱食 +\(item.hungerBoost)\n消耗能量 \(item.costEnergy)"
            purchaseToast = ("能量 -\(item.costEnergy)", .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if case let (_, timestamp)? = purchaseToast,
                   Date().timeIntervalSince(timestamp) > 1.0 {
                    purchaseToast = nil
                }
            }
        } else {
            alertMessage = "能量不足，完成任务可获得能量哦"
        }
    }
}
