import Foundation

enum PetActionType {
    case pat
    case feed(item: Item)
}

@MainActor
final class PetEngine {
    func handleAction(_ action: PetActionType, pet: Pet) {
        switch action {
        case .pat:
            pet.bonding = nextBonding(from: pet.bonding, boost: 1)
            pet.hunger = max(0, pet.hunger - 2)
        case .feed(let item):
            pet.hunger = min(100, pet.hunger + item.hungerBoost)
            pet.bonding = nextBonding(from: pet.bonding, boost: item.BondingBoost / 4)
        }
    }

    func applyTaskCompletion(pet: Pet) {
        pet.bonding = nextBonding(from: pet.bonding, boost: 2)
        pet.hunger = max(0, pet.hunger - 5)
        awardXP(1, to: pet)
    }

    func applyPurchaseReward(pet: Pet, xpGain: Int = 1, bondingBoost: Int = 20) {
        let steps = max(1, bondingBoost / 20)
        pet.bonding = nextBonding(from: pet.bonding, boost: steps)
        awardXP(xpGain, to: pet)
    }

    private func nextBonding(from bonding: PetBonding, boost: Int) -> PetBonding {
        let ordered: [PetBonding] = [.sleepy, .calm, .happy, .ecstatic]
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
}
