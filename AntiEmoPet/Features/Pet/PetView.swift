import SwiftUI
import Combine

struct PetView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var viewModel = PetViewModel()
	private let moodModel = MoodStatisticsViewModel()
	@State private var mood: MoodStatisticsViewModel.MoodSummary = .empty
	@State private var activeSheet: ActiveSheet?
	@State private var taskOffset: CGSize = .zero
	@State private var taskBreathUp: Bool = false
	@State private var taskFloatTask: Task<Void, Never>?
	@State private var showPettingHearts = false
	@State private var pettingEffectTask: Task<Void, Never>?
	@State private var activeReward: RewardEvent?
	@State private var rewardOpacity: Double = 0
	@State private var bannerTask: Task<Void, Never>?
	@State private var showMoodFeedback = false
	@State private var appearOpacity: Double = 0
	@State private var navigateToChatFromPrompt = false
	@State private var promptComfortValue: Int?

   private var isInteractionLocked: Bool {
      (appModel.showMoodCapture && !appModel.showOnboarding) || activeReward != nil || showMoodFeedback || appModel.showMoodChatPrompt
   }

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

    		content()
        		.zIndex(activeSheet == .shop ? 5 : 0)

			controlOverlay
				   .zIndex(activeSheet == .shop ? 0 : 3)

			overlayLayers
				   .zIndex(10)

			NavigationLink(isActive: $navigateToChatFromPrompt) {
				   ChatView(initialComfortMood: promptComfortValue)
				   .environmentObject(appModel)
				} label: {
					   EmptyView()
				}
				.buttonStyle(.plain)
				.hidden()
			}
            .opacity(appearOpacity)
		
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .tasks:
                sheetStyled(TasksView(lastMood: mood.lastMood))
            case .shop:
                sheetStyled(ShopView())
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                appearOpacity = 1
            }
            viewModel.sync(with: appModel)
            if let summary = moodModel.moodSummary(entries: appModel.moodEntries) {
                mood = summary
            }
        }
        .onReceive(appModel.$pet) { pet in
            viewModel.updateStatus(stats: appModel.userStats, pet: pet)
            viewModel.updatePetState(pet: pet)
        }
        .onReceive(appModel.$userStats) { stats in
            viewModel.updateStatus(stats: stats, pet: appModel.pet)
        }
        .onChange(of: appModel.weather) { _, weather in
            viewModel.updateScene(weather: weather)
        }
        .onReceive(appModel.$moodEntries) { entries in
            if let summary = moodModel.moodSummary(entries: entries) {
                mood = summary
            }
        }
        .onReceive(appModel.objectWillChange) { _ in
            viewModel.updateStatus(stats: appModel.userStats, pet: appModel.pet)
            viewModel.updatePetState(pet: appModel.pet)
        }
        .onChange(of: activeSheet) { _, newValue in
            if newValue != .shop {
                appModel.previewPetAsset = nil
            }
        }
        .onChange(of: appModel.rewardBanner) { _, newValue in
            guard let reward = newValue else { return }
            if activeSheet == .tasks {
                activeSheet = nil
            }
            activeReward = reward
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                rewardOpacity = 1
            }
            bannerTask?.cancel()
            bannerTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.easeInOut(duration: 1.5)) {
                    rewardOpacity = 0
                }
                appModel.consumeRewardBanner()
                activeReward = nil

                if appModel.pendingMoodFeedbackTask != nil {
                    await MainActor.run {
                        withAnimation(.spring(response: 1, dampingFraction: 0.8)) {
                            showMoodFeedback = true
                        }
                    }
                }
            }
        }
        .onChange(of: appModel.pendingMoodFeedbackTask) { _, newValue in
        		if newValue != nil {
            if activeSheet == .tasks {
            		activeSheet = nil
            }
            if activeReward == nil {
            		withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showMoodFeedback = true
            		}
            }
        		} else {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            		showMoodFeedback = false
            }
            appModel.checkAndShowOnboardingCelebration()
        		}
        }
        .onDisappear {
            bannerTask?.cancel()
        }
    }

    @ViewBuilder
    private func sheetStyled<Content: View>(_ content: Content) -> some View {
        content
            .presentationDetents([.fraction(0.55)])
            .presentationBackground { sheetBackground }
            .presentationDragIndicator(.hidden)
    }

		@ViewBuilder
		private var sheetBackground: some View {
				if #available(iOS 26, *) {
						liquidGlassBackground
				} else {
						Rectangle()
								.fill(.thinMaterial)
				}
		}

		private var liquidGlassBackground: some View {
				Rectangle()
						.fill(.ultraThinMaterial)
						.opacity(0.4)
						.overlay(
								LinearGradient(
										colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
										startPoint: .topLeading,
										endPoint: .bottomTrailing
								)
						)
						.shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)
		}

		@ViewBuilder
		private func content() -> some View {
				if let pet = appModel.pet {
						VStack(alignment: .leading) {
								topBar
									.padding(.vertical, .h(0.03))
									.padding(.horizontal, .w(0.12))
								
								Spacer(minLength: 0) // Remove fixed spacer
								
								petStage(for: pet)
								
								Spacer(minLength: 50)
			}
			.overlay(alignment: .top) {
				pettingNoticeOverlay()
					.padding(.top, .h(0.05))
			}
		} else {
			VStack(spacing: .h(0.1)) {
				Image(systemName: "pawprint.circle")
					.foregroundStyle(.white.opacity(0.85))
				Text("You'll meet Lumio after onboarding")
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
			.background(FrostedCapsule(opacity: 0.25))

			Spacer()
		}
		}

		private func petStage(for pet: Pet) -> some View {
				ZStack(alignment: .bottomTrailing) {
					Image(petAssetName)
						.resizable()
						.scaledToFit()
						.frame(maxWidth: .w(0.4), maxHeight: .h(0.25))
						.padding(20)
						.shadow(color: .black.opacity(0.2), radius: 10, x: -5, y: 5)
						.simultaneousGesture(
								TapGesture()
										.onEnded { triggerPettingInteraction() }
						)
						.simultaneousGesture(
								DragGesture(minimumDistance: 30)
										.onEnded { value in
												let vertical = abs(value.translation.height)
												let horizontal = abs(value.translation.width)
												if vertical > horizontal, vertical > 50 {
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
				.offset(y: activeSheet == .shop ? -.h(0.3) : 0)
				.animation(.spring(response: 0.3, dampingFraction: 0.85), value: activeSheet)
				.onDisappear {
						pettingEffectTask?.cancel()
						showPettingHearts = false
				}
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
				.frame(width: 75)
				.accessibilityLabel("tasks")
				.shadow(color: Color.black.opacity(0.1), radius: 6, x: 1, y: 1)
		}
		// 随机漂移 + 上下 的综合 offset
		.offset(
			x: taskOffset.width,
			y: taskOffset.height + (taskBreathUp ? -15 : 15)
		)
		// 轻微缩放“呼吸”效果
		.scaleEffect(taskBreathUp ? 1 : 0.8)
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
				.frame(width: 90)
				.shadow(color: Color.gray.opacity(0.2), radius: 8, x: 2, y: 2)
		}
		.buttonStyle(.borderless)
	}

	private var MoreButton: some View {
			NavigationLink(
					destination: MoreView(energyHistory: appModel.energyHistory)
							.environmentObject(appModel)
			) {
		Image(systemName: "ellipsis.circle")
			.appFont(FontTheme.title)
			.padding(12)
					.foregroundStyle(.white)
			}
			.buttonStyle(.plain)
	}

	private var chatEntryBar: some View {
		HStack(spacing: 12) {
			Button {
				appModel.startManualMoodCapture()
			} label: {
				Image(systemName: "plus")
					.appFont(FontTheme.title3)
					.bold()
					.foregroundStyle(.white)
					.padding(10)
					.background(FrostedCircle(opacity: 0.5))
				}
			.buttonStyle(.plain)

			NavigationLink {
				ChatView()
					.environmentObject(appModel)
				} label: {
						HStack(alignment: .center, spacing: 12) {
							Text("Share your feelings and thoughts")
								.foregroundStyle(.white.opacity(0.85))
							Spacer(minLength: 0)
							Image(systemName: "paperplane.fill")
									.appFont(FontTheme.headline)
									.foregroundStyle(.white.opacity(0.85))
								}
								.padding(.vertical, 10)
								.padding(.horizontal, 14)
								.background(FrostedCapsule(opacity: 0.5))
				}
				.buttonStyle(.plain)
			}
			.padding(12)
	}



		@ViewBuilder
		private func decorationStack(for decorations: [String]) -> some View {
				let catalog = Dictionary(uniqueKeysWithValues: appModel.shopItems.map { ($0.assetName, $0.type) })
				let layered = decorations.filter { !$0.isEmpty }

				let uniqueByType = layered.reversed().reduce(into: [(String, ItemType?)]()) { result, asset in
						let type = catalog[asset]
						guard !result.contains(where: { $0.1 == type }) else { return }
						result.append((asset, type))
				}.reversed().map { $0.0 }

				let visible = Array(uniqueByType.prefix(3))
				if !visible.isEmpty {
						HStack(spacing: -12) {
								ForEach(Array(visible.enumerated()), id: \.offset) { index, asset in
										Image(asset)
												.resizable()
												.scaledToFit()
												.frame(width: max(80, 120 - CGFloat(index) * 10))
												.shadow(color: .gray.opacity(0.2), radius: 5, x: 1, y: 1)
								}
						}
						.padding(12)
						.transition(.opacity.combined(with: .move(edge: .trailing)))
				}
		}

	private func startTaskFloating() {
		guard taskFloatTask == nil else { return }

		taskFloatTask = Task { @MainActor in
			// 上下 + 轻微缩放
			withAnimation(
				.easeInOut(duration: 8)
					.repeatForever(autoreverses: true)
			) {
				taskBreathUp = true
			}
			// 循环随机改变基础偏移量，实现“缓慢随机游走”
			while !Task.isCancelled {
				let newX = CGFloat.random(in: -.w(0.25)...0)
				let newY = CGFloat.random(in: -.h(0.08)...0)

				withAnimation(.easeInOut(duration: 15)) {
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
		guard appModel.petting() else { return }
	
		let generator = UIImpactFeedbackGenerator(style: .soft)
		generator.impactOccurred()
		
		pettingEffectTask?.cancel()
		withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
				showPettingHearts = true
		}
		pettingEffectTask = Task { @MainActor in
			try? await Task.sleep(nanoseconds: 500_000_000)
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
						.appFont(FontTheme.title)
						.foregroundStyle(Color.pink.opacity(0.85 - Double(index) * 0.25))
						.offset(x: CGFloat(index * 5), y: CGFloat(-240 - index * 5))
						.scaleEffect(1 + CGFloat(index) * 0.2)
				}
			}
		}
	}

	@ViewBuilder
	private func pettingNoticeOverlay() -> some View {
		if let notice = appModel.pettingNotice {
			Text(notice)
				.appFont(FontTheme.subheadline)
				.padding(12)
				.background(.ultraThinMaterial, in: Capsule())
				.shadow(radius: 6)
				.transition(.move(edge: .top).combined(with: .opacity))
		}
	}

	
	@ViewBuilder
	private var controlOverlay: some View {
		ZStack {
				// Base UI: top-right more/tasks buttons
				VStack(alignment: .trailing, spacing: .h(0.15)) {
						MoreButton
								.padding(.trailing, .w(0.1))
								.padding(.top, .h(0.02))
						taskButton
								.padding(.trailing, .w(0.05))
								.opacity(0.8)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

				// Base UI: bottom-left shop button
				shopButton
						.offset(x: .w(0.1), y: -.h(0.15))
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

				chatEntryBar
						.padding(.horizontal, .w(0.08))
						.padding(.bottom, .h(0.025))
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}

	@ViewBuilder
	private var overlayLayers: some View {
           ZStack {
              if isInteractionLocked {
				 Color.clear
				 .ignoresSafeArea()
				 .zIndex(5)
           }

           // Overlays ABOVE the buttons
           if appModel.showMoodCapture && !appModel.showOnboarding {
              MoodCaptureOverlayView() { value in
				  appModel.recordMoodOnLaunch(value: value)
            }
           .frame(maxWidth: 360)
           .offset(y: -UIScreen.main.bounds.height * 0.1)
           .transition(.scale(scale: 0.9).combined(with: .opacity))
           .zIndex(10)
   }

   if appModel.showMoodChatPrompt {
			Color.clear
				  .ignoresSafeArea()
				  .zIndex(14)

			MoodChatPromptView(
				onMaybeLater: {appModel.dismissMoodChatPrompt(clearValue: true)},
			  onConfirm: {
					  promptComfortValue = promptComfortValue ?? appModel.consumeComfortMoodValue()
					  appModel.dismissMoodChatPrompt()
					  navigateToChatFromPrompt = true
			  }
           )
           .frame(maxWidth: 320)
           .padding(.horizontal)
           .offset(y: -UIScreen.main.bounds.height * 0.15)
           .transition(.scale(scale: 0.9).combined(with: .opacity))
           .zIndex(15)
   }

	   if let reward = activeReward {
			   Color.clear
					.ignoresSafeArea()
					.zIndex(19)
			RewardToastView(event: reward)
				.opacity(rewardOpacity)
				.padding(12)
				.transition(.scale(scale: 0.9).combined(with: .opacity))
				.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
				.offset(y: -UIScreen.main.bounds.height * 0.15)
				.zIndex(20)
		}

		if showMoodFeedback, let task = appModel.pendingMoodFeedbackTask {
			Color.clear
				.ignoresSafeArea()
				.transition(.opacity)
				.zIndex(29)
			MoodFeedbackOverlayView(
				taskCategory: task.category
			)
			.frame(maxWidth: 360)
			.offset(y: -UIScreen.main.bounds.height * 0.1)
			.transition(.scale(scale: 0.9).combined(with: .opacity))
			.zIndex(30)
		}

		if appModel.showOnboardingCelebration {
				Color.black.opacity(0.35)
						.ignoresSafeArea()
						.transition(.opacity)
						.zIndex(39)
			OnboardingCelebrationView {
				appModel.dismissOnboardingCelebration()
			}
			.frame(maxWidth: 360)
			.padding()
			.offset(y: UIScreen.main.bounds.height * 0.18)
			.transition(.scale(scale: 0.9).combined(with: .opacity))
			.zIndex(40)
		}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.animation(.spring(response: 1, dampingFraction: 0.8), value: appModel.pendingMoodFeedbackTask)
		.animation(.spring(response: 1, dampingFraction: 0.8), value: appModel.showMoodCapture)
		}

		private var petAssetName: String {
    		viewModel.screenState.petAsset
		}

	
}
