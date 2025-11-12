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
        pet.xp += 1
        if pet.xp >= 10 {
            pet.level += 1
            pet.xp = 0
        }
    }

    private func nextBonding(from bonding: PetBonding, boost: Int) -> PetBonding {
        let ordered: [PetBonding] = [.sleepy, .calm, .happy, .ecstatic]
        guard let index = ordered.firstIndex(of: bonding) else { return bonding }
        let newIndex = min(ordered.count - 1, index + boost)
        return ordered[newIndex]
    }
}
