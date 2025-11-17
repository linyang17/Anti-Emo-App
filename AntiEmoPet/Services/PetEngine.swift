import Foundation

enum PetActionType {
    case pat
    case feed(item: Item)
	case penalty
}

@MainActor
final class PetEngine {
    func handleAction(_ action: PetActionType, pet: Pet) {
        switch action {
        case .pat:
            pet.bonding = nextBonding(from: pet.bonding, boost: 1)
        case .feed(let item):
            pet.bonding = nextBonding(from: pet.bonding, boost: item.BondingBoost / 4)
		case .penalty:
			pet.bonding = downgradeBonding(from: pet.bonding, drop: 1)
        }
    }

    func applyTaskCompletion(pet: Pet) {
        pet.bonding = nextBonding(from: pet.bonding, boost: 2)
        awardXP(1, to: pet)
    }

	func applyLightPenalty(to pet: Pet) {
		pet.bonding = downgradeBonding(from: pet.bonding, drop: 1)
	}

    func applyPurchaseReward(pet: Pet, xpGain: Int = 1, bondingBoost: Int = 20) {
        let steps = max(1, bondingBoost / 20)
        pet.bonding = nextBonding(from: pet.bonding, boost: steps)
        awardXP(xpGain, to: pet)
    }

    private func nextBonding(from bonding: PetBonding, boost: Int) -> PetBonding {
        let ordered: [PetBonding] = [.sleepy, .curious, .happy, .ecstatic]
        guard let index = ordered.firstIndex(of: bonding) else { return bonding }
        let newIndex = min(ordered.count - 1, index + boost)
        return ordered[newIndex]
    }

    private func awardXP(_ amount: Int, to pet: Pet) {
        guard amount > 0 else { return }
        pet.xp += amount
        if pet.xp >= 10 {
            pet.level += 1
            pet.xp = 0
        }
    }

	private func downgradeBonding(from bonding: PetBonding, drop: Int) -> PetBonding {
		let ordered: [PetBonding] = [.sleepy, .curious, .happy, .ecstatic]
		guard let index = ordered.firstIndex(of: bonding) else { return bonding }
		let newIndex = max(0, index - drop)
		return ordered[newIndex]
	}
}
