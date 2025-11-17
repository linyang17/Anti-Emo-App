import SwiftUI

struct PetView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var viewModel = PetViewModel()
	@State private var activeSheet: ActiveSheet?
	@State private var taskOffset: CGSize = .zero
	@State private var taskBreathUp: Bool = false
	@State private var taskFloatTask: Task<Void, Never>?
	@State private var showPettingHearts = false
	@State private var pettingEffectTask: Task<Void, Never>?

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
				MoreButton
					.padding(32)
				taskButton
					.padding(12)
			}
		}
		.overlay(alignment: .bottomLeading) {
			shopButton
				.padding(.leading, 40)
				.padding(.bottom, 130)
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
					.padding(.vertical, 24)
					.padding(.horizontal, 44)
				Spacer(minLength: 24)
				petStage(for: pet)
					.padding(24)
			}
		} else {
			VStack(spacing: 16) {
				Image(systemName: "pawprint.circle")
					.font(.app(64))
					.foregroundStyle(.white.opacity(0.85))
				Text("You'll meet Lumio after onboarding!")
					.appFont(FontTheme.subheadline)
					.foregroundStyle(.white.opacity(0.75))
			}
			.padding(32)
			.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
			.padding()
		}
	}

	private var topBar: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading, spacing: 6) {
				statusChip(icon: "bolt.fill", value: "\(viewModel.statusSummary.energy)")
				statusChip(icon: "heart.fill", value: "\(viewModel.statusSummary.bond)")
				statusChip(icon: "star.circle.fill", value: "\(viewModel.statusSummary.levelLabel)")
				HStack {
					Spacer()
					ProgressView(value: viewModel.statusSummary.experienceProgress)
						.tint(.orange)
						.frame(width: 40)
						}
			}
			.frame(width: 66)
			.padding(10)
			.background(statusBackground)

			Spacer()
		}
	}

	private func petStage(for pet: Pet) -> some View {
		ZStack(alignment: .bottomTrailing) {
			Image(viewModel.screenState.petAsset)
				.resizable()
				.scaledToFit()
				.frame(maxWidth: 220)
				.padding(.top, 120)
				.padding(.bottom, 120)
				.shadow(color: .black.opacity(0.2), radius: 10, x: -5, y: 5)
				.simultaneousGesture(
					TapGesture()
						.onEnded { triggerPettingInteraction() }
				)
				.simultaneousGesture(
					DragGesture(minimumDistance: 20)
						.onEnded { value in
							let vertical = abs(value.translation.height)
							let horizontal = abs(value.translation.width)
							if vertical > horizontal, vertical > 30 {
								triggerPettingInteraction()
							}
						}
				)
				.accessibilityAction(named: Text("Pet Lumio")) {
					triggerPettingInteraction()
				}

			if showPettingHearts {
				PettingHeartBurst()
					.transition(.opacity)
			}

			decorationStack(for: pet.decorations)
		}
		.frame(maxWidth: .infinity)
		.onDisappear {
			pettingEffectTask?.cancel()
			showPettingHearts = false
		}
	}

	private var statusBackground: some View {
		RoundedRectangle(cornerRadius: 12)
			.fill(.ultraThinMaterial.opacity(0.2))
			.shadow(color: .white.opacity(0.2), radius: 4, x: -1, y: -1)
			.shadow(color: .purple.opacity(0.2), radius: 6, x: 1, y: 1)
	}

	private func statusChip(icon: String, value: String) -> some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.appFont(FontTheme.subheadline)
				.fontWeight(.semibold)
				.foregroundStyle(.white)
				.frame(width: 8)
				.padding(4)
			Text(value)
				.appFont(FontTheme.headline)
				.fontWeight(.semibold)
				.foregroundStyle(.white)
		}
	}

	private var taskButton: some View {
		Button {
			activeSheet = .tasks
		} label: {
			Image("spaceship")
				.resizable()
				.scaledToFit()
				.frame(width: 90)
				.accessibilityLabel("查看任务")
				.shadow(color: Color.gray.opacity(0.2), radius: 8, x: 1, y: 1)
		}
		// 随机漂移 + 垂直呼吸 的综合 offset
		.offset(
			x: taskOffset.width,
			y: taskOffset.height + (taskBreathUp ? -10 : 10)
		)
		// 轻微缩放“呼吸”效果
		.scaleEffect(taskBreathUp ? 1 : 0.9)
		.onAppear {
			startTaskFloating()
		}
		.onDisappear {
			stopTaskFloating()
		}
		.buttonStyle(.borderless)
	}

	private var shopButton: some View {
		Button {
			activeSheet = .shop
		} label: {
			Image("giftbox")
				.resizable()
				.scaledToFit()
				.frame(width: 100)
				.accessibilityLabel("打开商店")
				.shadow(color: Color.gray.opacity(0.2), radius: 8, x: 2, y: 2)
		}
		.buttonStyle(.borderless)
	}

	private var MoreButton: some View {
		NavigationLink(destination: MoreView().environmentObject(appModel)) {
			Image(systemName: "ellipsis")
				.font(.app(20))
				.fontWeight(.bold)
				.padding(8)
				.foregroundStyle(.white)
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
						.shadow(color: .gray.opacity(0.2), radius: 5, x: 1, y: 1)
						.offset(y: CGFloat(index) * -4)
				}
			}
			.padding(.trailing, 6)
			.padding(.bottom, 12)
			.transition(.opacity.combined(with: .move(edge: .trailing)))
		}
	}

	private func startTaskFloating() {
		guard taskFloatTask == nil else { return }

		taskFloatTask = Task { @MainActor in
			// 先启动持续的“呼吸”动画（上下 + 轻微缩放）
			withAnimation(
				.easeInOut(duration: 8)
					.repeatForever(autoreverses: true)
			) {
				taskBreathUp = true
			}
			// 然后循环随机改变基础偏移量，实现“缓慢随机游走”
			while !Task.isCancelled {
				let newX = CGFloat.random(in: -90...0)
				let newY = CGFloat.random(in: -30...30)

				withAnimation(.easeInOut(duration: 10)) {
					taskOffset = CGSize(width: newX, height: newY)
				}
				try? await Task.sleep(nanoseconds: 3_000_000_000)
			}
		}
	}

	private func stopTaskFloating() {
		taskFloatTask?.cancel()
		taskFloatTask = nil
	}

	private func triggerPettingInteraction() {
		appModel.petting()
		pettingEffectTask?.cancel()
		withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
			showPettingHearts = true
		}
		pettingEffectTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 1_200_000_000)
			withAnimation(.easeOut(duration: 0.3)) {
				showPettingHearts = false
			}
		}
	}

	private struct PettingHeartBurst: View {
		var body: some View {
			ZStack {
				ForEach(0..<3) { index in
					Image(systemName: "heart.fill")
						.font(.system(size: 32))
						.foregroundStyle(Color.pink.opacity(0.85 - Double(index) * 0.2))
						.offset(x: CGFloat(index * 14 - 14), y: CGFloat(-50 - index * 20))
						.scaleEffect(1 + CGFloat(index) * 0.2)
				}
			}
		}
	}
	
	@ViewBuilder
	private func presentSheet(for sheet: ActiveSheet) -> some View {
		switch sheet {
		case .tasks:
			TasksView()
			.environmentObject(appModel)
			.presentationDetents([.fraction(0.55)])
			.presentationBackground(.thickMaterial.opacity(0.7))
			.presentationDragIndicator(.hidden)
		case .shop:
			ShopView()
				.environmentObject(appModel)
				.presentationDetents([.fraction(0.6)])
				.presentationBackground(.ultraThickMaterial.opacity(0.7))
				.presentationDragIndicator(.hidden)
		}
	}
}
