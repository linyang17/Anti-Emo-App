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
                        Label(sectionTitle(for: section.type), systemImage: section.type.icon)
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
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) { toastView }
        .animation(.spring(duration: 0.3), value: purchaseToast != nil)
        .navigationTitle("装扮商店")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("当前能量：\(appModel.userStats?.totalEnergy ?? 0)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Lumio 装扮商店")
                .font(.largeTitle.bold())
            Text("用完成任务获得的能量兑换配饰，让 Lumio 在冒险途中展现不同的模样。")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                statusBadge(title: "能量", value: "\(appModel.userStats?.totalEnergy ?? 0)", icon: "bolt.fill")
                statusBadge(title: "金币", value: "\(appModel.userStats?.coins ?? 0)", icon: "sparkles")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func shopCard(for item: Item) -> some View {
        let ownedCount = appModel.inventory.first(where: { $0.sku == item.sku })?.count ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text("拥有 \(ownedCount) 件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(item.costEnergy) ⚡️")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.accentColor)
            }

            Text("心情 +\(item.moodBoost) · 饱食 +\(item.hungerBoost)")
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

    private func statusBadge(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.semibold))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
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

    private func sectionTitle(for type: ItemType) -> String {
        switch type {
        case .snack:
            return "补给"
        case .toy:
            return "玩具"
        case .decor:
            return "装扮"
        }
    }

    private func handlePurchase(_ item: Item) {
        if appModel.purchase(item: item) {
            alertMessage = "已兑换：\(item.name)\n心情 +\(item.moodBoost) · 饱食 +\(item.hungerBoost)\n消耗能量 \(item.costEnergy)"
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
