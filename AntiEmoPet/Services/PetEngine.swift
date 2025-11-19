import Foundation

enum PetActionType {
	case pat
	case feed(item: Item)
	case penalty
}

struct XPProgression {
	static func requirement(for level: Int) -> Int {
		switch level {
		case ..<1: return 10
		case 1: return 10
		case 2: return 25
		case 3: return 50
		case 4: return 75
		case 5: return 100
		default: return 100
		}
	}
}

@MainActor
final class PetEngine {

	private enum Constants {
		static let minScore = 10
		static let maxScore = 100
	}

	// 使用弱引用保存宠物，而不是整个 AppViewModel
	private weak var pet: Pet?

	init(pet: Pet?) {
		self.pet = pet
	}

	// 当 AppViewModel.pet 变化时更新引用
	func updatePetReference(_ newPet: Pet?) {
		self.pet = newPet
	}

	// MARK: - 动作处理
        func handleAction(_ action: PetActionType) {
                guard let pet else { return }

                switch action {
                case .pat:
                        updateBonding(for: pet, bondingAddValue: 1)
                case .feed:
                        updateBonding(for: pet, bondingAddValue: 2)
                        awardXP(2, to: pet)
                case .penalty:
                        updateBonding(for: pet, bondingAddValue: -1)
		}
	}

	func applyTaskCompletion() {
		guard let pet else { return }
		updateBonding(for: pet, bondingAddValue: 1)
		awardXP(1, to: pet)
	}

	func applyLightPenalty() {
		guard let pet else { return }
		updateBonding(for: pet, bondingAddValue: -1)
	}

	func applyDailyDecay(days: Int) {
		guard let pet, days > 0 && pet.bondingScore > 20 else { return }
		updateBonding(for: pet, bondingAddValue: -(days * 2))
	}

	func applyPurchaseReward(xpGain: Int, bondingBoost: Int) {
		guard let pet else { return }
		updateBonding(for: pet, bondingAddValue: bondingBoost)
		awardXP(xpGain, to: pet)
	}

        func applyPettingReward() {
                guard let pet else { return }
                updateBonding(for: pet, bondingAddValue: 1)
        }

	// MARK: - 核心计算逻辑
	private func updateBonding(for pet: Pet, bondingAddValue: Int) {
		let newScore = clamp(pet.bondingScore + bondingAddValue)
		pet.bondingScore = newScore
	}

	private func clamp(_ value: Int) -> Int {
		min(Constants.maxScore, max(Constants.minScore, value))
	}

	private func awardXP(_ amount: Int, to pet: Pet) {
		guard amount > 0 else { return }

		var totalXP = pet.xp + amount
		var level = pet.level

		while true {
			let requirement = max(1, XPProgression.requirement(for: level))
			if totalXP >= requirement {
				totalXP -= requirement
				level += 1
			} else {
				break
			}
		}

		pet.level = level
		pet.xp = totalXP
	}
}
