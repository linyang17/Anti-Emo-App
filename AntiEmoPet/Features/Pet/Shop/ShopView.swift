import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = ShopViewModel()
    @State private var alertMessage: String?
    @State private var selectedCategory: ItemType = ItemType.allCases.first ?? .decor
    @State private var pendingItem: Item?
    @State private var purchaseToast: ShopToast?

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                shopPanel
            }
        }
        .overlay(alignment: .top) { toastView }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pendingItem?.id)
        .onAppear {
            selectedCategory = viewModel.defaultCategory(in: appModel.shopItems)
        }
        .onChange(of: selectedCategory) { _ in
            pendingItem = nil
        }
        .onChange(of: appModel.shopItems) { items in
            if !items.contains(where: { $0.type == selectedCategory }) {
                selectedCategory = viewModel.defaultCategory(in: items)
            }
        }
        .alert(
            "提示",
            isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })
        ) {
            Button("好的", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var shopPanel: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: 48, height: 4)

            Text("Shop")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            statusRow
            categoryPicker
            gridSection

            if let pendingItem, !isOwned(pendingItem) {
                confirmButton(for: pendingItem)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(glassBackground)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    private var statusRow: some View {
        HStack(spacing: 16) {
            statusBadge(
                icon: "bolt.fill",
                title: "Energy",
                value: "\(appModel.userStats?.totalEnergy ?? 0)"
            )
            statusBadge(
                icon: "heart.fill",
                title: "Bonding",
                value: appModel.pet?.bonding.displayName ?? "--"
            )
        }
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(ItemType.allCases, id: \.self) { type in
                Button {
                    selectedCategory = type
                } label: {
                    Text(type.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedCategory == type ? .black : .white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Group {
                                if selectedCategory == type {
                                    Color.white.opacity(0.9)
                                } else {
                                    Color.white.opacity(0.2)
                                }
                            }
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.white.opacity(0.15), in: Capsule())
    }

    private var gridSection: some View {
        let items = viewModel.items(for: selectedCategory, in: appModel.shopItems, limit: viewModel.gridCapacity)
        let placeholders = max(0, viewModel.gridCapacity - items.count)

        return LazyVGrid(columns: columns, spacing: 18) {
            ForEach(items) { item in
                Button {
                    handleTap(on: item)
                } label: {
                    shopCard(
                        for: item,
                        isSelected: pendingItem?.id == item.id,
                        isOwned: isOwned(item),
                        isEquipped: appModel.isEquipped(item)
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(0..<placeholders, id: \.self) { _ in
                placeholderCard
            }
        }
        .padding(.top, 4)
    }

    private func shopCard(for item: Item, isSelected: Bool, isOwned: Bool, isEquipped: Bool) -> some View {
        VStack(spacing: 10) {
            itemImage(for: item)
            Text(item.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if isOwned {
                HStack(spacing: 6) {
                    Image(systemName: isEquipped ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isEquipped ? Color.accentColor : .white.opacity(0.7))
                    Text(isEquipped ? "展示中" : "展示")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(item.costEnergy)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [Color.white.opacity(0.65), Color.white.opacity(0.15)]
                            : [Color.white.opacity(isOwned ? 0.4 : 0.3), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.35), lineWidth: isSelected ? 1.5 : 0.8)
        )
        .shadow(color: .black.opacity(isSelected ? 0.35 : 0.2), radius: isSelected ? 16 : 10, x: 0, y: isSelected ? 10 : 6)
    }

    @ViewBuilder
    private func itemImage(for item: Item) -> some View {
        if !item.assetName.isEmpty {
            Image(item.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
        } else {
            Image(systemName: "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.white)
                .padding(12)
                .background(Circle().fill(Color.white.opacity(0.25)))
        }
    }

    private var placeholderCard: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(height: 150)
            .overlay(
                Text("补货中")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }

    private func confirmButton(for item: Item) -> some View {
        Button {
            confirmPurchase(of: item)
        } label: {
            Text("Confirm")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func statusBadge(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.15), in: Capsule())
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 40, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 20)
    }

    private func handleTap(on item: Item) {
        if isOwned(item) {
            toggleSelection(for: item)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if pendingItem?.id == item.id {
                    pendingItem = nil
                } else {
                    pendingItem = item
                }
            }
        }
    }

    private func toggleSelection(for item: Item) {
        if appModel.isEquipped(item) {
            appModel.unequip(item: item)
        } else {
            appModel.equip(item: item)
        }
    }

    private func confirmPurchase(of item: Item) {
        if appModel.purchase(item: item) {
            appModel.equip(item: item)
            showToast(for: item)
            pendingItem = nil
        } else {
            alertMessage = "能量不足，完成任务可获得能量哦"
        }
    }

    private func showToast(for item: Item) {
        let toast = ShopToast(message: "能量 -\(item.costEnergy) · XP +1 · Bonding +20")
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            purchaseToast = toast
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if purchaseToast?.id == toast.id {
                withAnimation(.easeInOut(duration: 0.25)) {
                    purchaseToast = nil
                }
            }
        }
    }

    private func isOwned(_ item: Item) -> Bool {
        appModel.inventory.first(where: { $0.sku == item.sku })?.count ?? 0 > 0
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast = purchaseToast {
            Text(toast.message)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

private struct ShopToast: Identifiable {
    let id = UUID()
    let message: String
}
