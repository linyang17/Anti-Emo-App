import SwiftUI

struct PetView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @StateObject private var viewModel = PetViewModel()
    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case tasks
        case shop

        var id: Int { hashValue }
    }

    var body: some View {
        ZStack {
            Image(viewModel.screenState.backgroundAsset)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            content
        }
        .overlay(alignment: .trailing) { rocketButton }
        .overlay(alignment: .bottom) { shopButton }
        .sheet(item: $activeSheet, content: presentSheet(for:))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.sync(with: appModel) }
        .onReceive(appModel.$pet) { pet in
            viewModel.updateStatus(stats: appModel.userStats, pet: pet)
            viewModel.updatePetState(pet: pet)
        }
        .onReceive(appModel.$userStats) { stats in
            viewModel.updateStatus(stats: stats, pet: appModel.pet)
        }
        .onReceive(appModel.$weather) { weather in
            viewModel.updateScene(weather: weather)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let pet = appModel.pet {
            VStack(alignment: .leading, spacing: 24) {
                topBar
                Spacer(minLength: 24)
                petStage(for: pet)
                Spacer(minLength: 24)
                interactionPanel(for: pet)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "pawprint.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.85))
                Text("尚未创建宠物")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("完成引导流程后，就能和 Lumio 在这里见面啦")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding()
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                statusChip(icon: "bolt.fill", title: "能量", value: "\(viewModel.statusSummary.energy)")
                statusChip(icon: "heart.fill", title: "关系", value: "\(viewModel.statusSummary.bond)")
                if appModel.pet != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(viewModel.statusSummary.levelLabel, systemImage: "star.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.white)
                        ProgressView(value: viewModel.statusSummary.experienceProgress)
                            .tint(.yellow)
                    }
                    .padding(12)
                    .background(statusBackground)
                }
            }

            Spacer()

            NavigationLink(destination: MoreView().environmentObject(appModel)) {
                Image(systemName: "arrow.turn.up.left")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
            }
            .accessibilityLabel("前往更多设置")
        }
    }

    private func petStage(for pet: Pet) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            Image(viewModel.screenState.petAsset)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
                .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)
                .accessibilityLabel("Lumio 正在等待你的互动")

            VStack(spacing: 8) {
                Text(pet.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text(viewModel.moodDescription(for: pet))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                if !viewModel.screenState.weatherDescription.isEmpty {
                    Text(viewModel.screenState.weatherDescription)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func interactionPanel(for pet: Pet) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                PrimaryButton(title: "摸摸 Lumio 🐾") {
                    appModel.petting()
                }

                NavigationLink(destination: BackpackView().environmentObject(appModel)) {
                    Label("背包", systemImage: "bag")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            if let snack = appModel.shopItems.first(where: { $0.type == .snack }),
               appModel.inventory.first(where: { $0.sku == snack.sku && $0.count > 0 }) != nil {
                PrimaryButton(title: "喂零食：\(snack.name) 🍪") {
                    appModel.useItem(sku: snack.sku)
                }
            } else {
                Text("🍪 背包没有零食，先去商店购买吧")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var statusBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.16))
    }

    private func statusChip(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text(value)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(statusBackground)
    }

    private var rocketButton: some View {
        VStack {
            Spacer()
            Button {
                activeSheet = .tasks
            } label: {
                Image(systemName: "rocket.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 8)
            }
            .accessibilityLabel("查看今日任务")
            Spacer()
        }
        .padding(.trailing, 24)
    }

    private var shopButton: some View {
        Button {
            activeSheet = .shop
        } label: {
            Label("前往商店", systemImage: "gift.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
        }
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private func presentSheet(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .tasks:
            NavigationStack {
                TasksView()
                    .environmentObject(appModel)
                    .navigationTitle("今日任务")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("完成") { activeSheet = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        case .shop:
            NavigationStack {
                ShopView()
                    .environmentObject(appModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("完成") { activeSheet = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
