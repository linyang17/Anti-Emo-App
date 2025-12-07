import SwiftUI


struct ShopView: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var viewModel = ShopViewModel()
	@State private var alertMessage: String?
	@State private var selectedCategory: ItemType = .decor
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
				selectedCategory = viewModel.availableCategories(in: appModel.shopItems).first ?? .snack
		}
		.onChange(of: selectedCategory) {
			pendingItem = nil
		}
		.onChange(of: appModel.shopItems) {
				let options = viewModel.availableCategories(in: appModel.shopItems)
				if !options.contains(selectedCategory) {
						selectedCategory = options.first ?? .snack
				}
		}
		.alert(
			"Oh no!",
			isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })
		) {
			Button("Okay", role: .cancel) { }
		} message: {
			Text(alertMessage ?? "")
		}
		.toolbar(.hidden, for: .navigationBar)
	}

	private var shopPanel: some View {
		VStack(spacing: 12) {
			categoryPicker
			
			ScrollView {
				ZStack(alignment: .bottom) {
					gridSection
						.padding(.bottom, 80) // Spacing for confirm button
					
					if let pendingItem, !isOwned(pendingItem) { }
				}
			}
			
			if let pendingItem, !isOwned(pendingItem) {
				confirmButton(for: pendingItem)
					.padding(.horizontal, 4)
					.padding(.bottom, 4)
					.transition(.move(edge: .bottom).combined(with: .opacity))
			}
		}
		.padding(.horizontal, 24)
		.padding(.top, 20)
		.padding(.bottom, 24)
		.frame(maxWidth: .infinity)
	}


	private var categoryPicker: some View {
                let options = viewModel.availableCategories(in: appModel.shopItems)
		return HStack(spacing: 8) {
                        ForEach(options, id: \.self) { type in
				Button {
					selectedCategory = type
				} label: {
					Text(type.displayName)
						.appFont(FontTheme.body)
						.foregroundStyle(.white)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 6)
						.background(
							Group {
								if selectedCategory == type {
									Color.brown.opacity(0.8)
								} else {
									Color.gray.opacity(0.3)
								}
							}
						)
						.clipShape(Capsule())
				}
				.buttonStyle(.plain)
			}
		}
		.padding(8)
	}

	private var gridSection: some View {
                                let items = viewModel.items(for: selectedCategory, in: appModel.shopItems)
                let placeholders = viewModel.placeholderCount(for: items)

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
                VStack(spacing: 6) {
                        itemImage(for: item)
                        Text(item.assetName)
                                .appFont(FontTheme.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(1)

                        if item.type == .snack {
                                HStack(spacing: 6) {
                                        Image(systemName: "bag.fill")
                                                .foregroundStyle(.white)
                                        Text("x \(snackQuantity(for: item))")
                                                .appFont(FontTheme.caption)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                }
                        } else if isOwned {
                                HStack(spacing: 6) {
                                        Image(systemName: isEquipped ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isEquipped ? Color.accentColor : .white.opacity(0.7))
                                }
                        } else {
                                HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                        Text("\(item.costEnergy)")
                                                .appFont(FontTheme.footnote)
                                                .fontWeight(.semibold)
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
                        .fill(Color.clear)
                        .frame(height: 150)
                        .overlay(
                                Text("Coming")
                                        .appFont(FontTheme.footnote)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white.opacity(0.6))
                        )
        }

        private func confirmButton(for item: Item) -> some View {
                Button {
                        confirmPurchase(of: item)
                } label: {
                        Text("Confirm")
                                .appFont(FontTheme.headline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(.white)
                                .background(Color.brown, in: Capsule())
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
                                        .appFont(FontTheme.footnote)
                                .foregroundStyle(.white.opacity(0.8))
                                Text(value)
                                        .appFont(FontTheme.subheadline)
                                        .fontWeight(.semibold)
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
							colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)],
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
                guard item.type != .snack else {
                        handleSnackTap(item)
                        return
                }

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

        private func handleSnackTap(_ item: Item) {
                guard snackQuantity(for: item) > 0 else {
                        alertMessage = "You're out of this snack right now."
                        return
                }

                let didFeed = appModel.feedSnack(item)
                if !didFeed {
                        alertMessage = "Unable to feed Lumio right now."
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
                guard item.type != .snack else {
                        alertMessage = "Snacks can only be earned from completing tasks."
                        pendingItem = nil
                        return
                }
                if appModel.purchase(item: item) {
                        appModel.equip(item: item)
                        showToast(for: item)
			pendingItem = nil
		} else {
			alertMessage = "You don't have enough energy, try to complete more tasks!"
		}
	}

	private func showToast(for item: Item) {
		let toast = ShopToast(
			message: "Energy -\(item.costEnergy) · XP + 10 · Bonding + \(item.bondingBoost)"
		)
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
                appModel.inventory.first(where: { $0.sku == item.sku })?.quantity ?? 0 > 0
        }

        private func snackQuantity(for item: Item) -> Int {
                appModel.inventory.first(where: { $0.sku == item.sku })?.quantity ?? 0
        }

	@ViewBuilder
	private var toastView: some View {
                if let toast = purchaseToast {
                        Text(toast.message)
                                .appFont(FontTheme.footnote)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.top, 20)
                                .transition(.move(edge: .top).combined(with: .opacity))
		}
	}
}

private struct ShopToast: Identifiable {
	let id = UUID()
	let message: String
}
