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
        .overlay(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: 120) {
                magicOrbButton
                taskButton
            }
            .padding(.trailing, 24)
            .padding(.top, 12)
        }
        .overlay(alignment: .bottomTrailing) {
            shopButton
                .padding(.trailing, 36)
                .padding(.bottom, 48)
        }
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
                Spacer(minLength: 8)
                petStage(for: pet)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "pawprint.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.85))
                Text("完成引导流程后，就能和 Lumio 在这里见面啦")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding()
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                statusChip(icon: "bolt.fill", value: "\(viewModel.statusSummary.energy)")
                statusChip(icon: "heart.fill", value: "\(viewModel.statusSummary.bond)")
                statusChip(icon: "star.circle.fill", value: "\(viewModel.statusSummary.levelLabel)")
                ProgressView(value: viewModel.statusSummary.experienceProgress)
                    .tint(.orange)
                    .frame(width: 70)
            }
            .padding(8)
            .background(statusBackground)

            Spacer()
        }
    }

    private func petStage(for pet: Pet) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(viewModel.screenState.petAsset)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)
                .shadow(color: .black.opacity(0.2), radius: 15, x: 5, y: 5)

            decorationStack(for: pet.decorations)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .padding(.horizontal, 16)
    }

	private var statusBackground: some View {
		RoundedRectangle(cornerRadius: 20)
			.fill(
				LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)],
							   startPoint: .topLeading,
							   endPoint: .bottomTrailing)
			)
			.background(.ultraThinMaterial)
			.shadow(color: .white.opacity(0.2), radius: 4, x: -2, y: -2)
			.shadow(color: .black.opacity(0.3), radius: 6, x: 3, y: 3)
	}

    private func statusChip(icon: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 8)
			Text(value)
				.font(.headline.weight(.semibold))
				.foregroundStyle(.white)
        }
		.padding(8)
    }

    private var taskButton: some View {
        Button {
            activeSheet = .tasks
        } label: {
            Image("spaceship")
                .resizable()
                .scaledToFit()
                .frame(width: 120)
                .accessibilityLabel("查看任务")
                .shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var shopButton: some View {
        Button {
            activeSheet = .shop
        } label: {
            Image("giftbox")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .accessibilityLabel("打开商店")
                .shadow(color: Color.accentColor.opacity(0.4), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var magicOrbButton: some View {
        NavigationLink(destination: MoreView().environmentObject(appModel)) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.9), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.purple.opacity(0.4), radius: 14, x: 0, y: 8)

                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 60, height: 60)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("更多设置")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func decorationStack(for decorations: [String]) -> some View {
        let visible = Array(decorations.filter { !$0.isEmpty }.prefix(3))
        if !visible.isEmpty {
            HStack(spacing: -12) {
                ForEach(Array(visible.enumerated()), id: \.offset) { index, asset in
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: max(80, 120 - CGFloat(index) * 10))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                        .offset(y: CGFloat(index) * -4)
                }
            }
            .padding(.trailing, 6)
            .padding(.bottom, 12)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    @ViewBuilder
    private func presentSheet(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .tasks:
            NavigationStack {
                TasksView()
                    .environmentObject(appModel)
            }
            .presentationDetents([.medium, .large])
        case .shop:
            ShopView()
                .environmentObject(appModel)
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.hidden)
        }
    }
}
