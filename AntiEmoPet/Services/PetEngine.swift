import Foundation

enum PetActionType {
    case pat
    case feed(item: Item)
	case penalty
}

@MainActor
final class PetEngine {
	private enum Constants {
		static let minScore = 10
		static let maxScore = 100
	}

    func handleAction(_ action: PetActionType, pet: Pet) {
        switch action {
        case .pat:
            updateBonding(for: pet, delta: 5)
        case .feed(let item):
            updateBonding(for: pet, delta: max(2, item.BondingBoost / 2))
		case .penalty:
			updateBonding(for: pet, delta: -5)
        }
    }

    func applyTaskCompletion(pet: Pet) {
        updateBonding(for: pet, delta: 8)
        awardXP(1, to: pet)
    }

	func applyLightPenalty(to pet: Pet) {
		updateBonding(for: pet, delta: -5)
	}

	func applyDailyDecay(pet: Pet, days: Int) {
		guard days > 0 else { return }
		updateBonding(for: pet, delta: -(days * 2))
	}

    func applyPurchaseReward(pet: Pet, xpGain: Int = 1, bondingBoost: Int = 20) {
        updateBonding(for: pet, delta: bondingBoost)
        awardXP(xpGain, to: pet)
    }

	private func updateBonding(for pet: Pet, delta: Int) {
		let newScore = clamp(pet.bondingScore + delta)
		pet.bondingScore = newScore
		pet.bonding = PetBonding.from(score: newScore)
	}

	private func clamp(_ value: Int) -> Int {
		min(Constants.maxScore, max(Constants.minScore, value))
	}

    private func awardXP(_ amount: Int, to pet: Pet) {
        guard amount > 0 else { return }
        pet.xp += amount
        if pet.xp >= 10 {
            pet.level += 1
            pet.xp = 0
        }
    }
}
