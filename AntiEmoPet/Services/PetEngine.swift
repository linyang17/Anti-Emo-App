import Foundation

enum PetActionType {
    case pat
    case feed(item: Item)
        case penalty
}

struct XPProgression {
        static func requirement(for level: Int) -> Int {
                switch level {
                case ..<1:
                        return 10
                case 1:
                        return 10
                case 2:
                        return 25
                case 3:
                        return 50
                case 4:
                        return 75
                case 5:
                        return 100
                default:
                        return 100
                }
        }
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
        case .feed:
                        updateBonding(for: pet, delta: 2)
                        awardXP(2, to: pet)
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

    func applyPurchaseReward(pet: Pet, xpGain: Int = 20, bondingBoost: Int = 10) {
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
