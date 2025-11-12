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
        .overlay(alignment: .trailing) { taskButton }
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

            NavigationLink(destination: MoreView().environmentObject(appModel)) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20, weight: .bold))
                    .padding(8)
                    .foregroundStyle(.white)
            }
        }
    }

    private func petStage(for pet: Pet) -> some View {
		
		Image(viewModel.screenState.petAsset)
			.resizable()
			.scaledToFit()
			.frame(maxHeight: 240)
			.shadow(color: .black.opacity(0.2), radius: 15, x: 5, y: 5)
		
        .frame(maxWidth: .infinity)
        .padding()
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
        VStack {
            Spacer()
            Button {
                activeSheet = .tasks
            } label: {
                Image("spaceship")
					.resizable()
					.scaledToFit()
					.frame(maxWidth: 80)
					.accessibilityHidden(true)
					.padding(18)
					.shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 8)
            }
        }
        .padding(.trailing, 30)
		.padding(.top, 200)
    }

    private var shopButton: some View {
        Button {
            activeSheet = .shop
        } label: {
			Image("giftbox")
				   .resizable()
				   .scaledToFit()
				   .frame(maxWidth: 100)
				   .accessibilityHidden(true)
				   .padding(18)
				   .shadow(color: Color.accentColor.opacity(0.4), radius: 14, x: 0, y: 8)
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
            }
            .presentationDetents([.medium, .large])
        case .shop:
            NavigationStack {
                ShopView()
                    .environmentObject(appModel)
            }
            .presentationDetents([.medium])
        }
    }
}
