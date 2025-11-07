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
            pet.mood = nextMood(from: pet.mood, boost: 1)
            pet.hunger = max(0, pet.hunger - 2)
        case .feed(let item):
            pet.hunger = min(100, pet.hunger + item.hungerBoost)
            pet.mood = nextMood(from: pet.mood, boost: item.moodBoost / 4)
        }
        pet.xp += 5
        if pet.xp >= 100 {
            pet.level += 1
            pet.xp = 0
        }
    }

    func applyTaskCompletion(pet: Pet) {
        pet.mood = nextMood(from: pet.mood, boost: 2)
        pet.hunger = max(0, pet.hunger - 5)
        pet.xp += 10
        if pet.xp >= 100 {
            pet.level += 1
            pet.xp = 0
        }
    }

    private func nextMood(from mood: PetMood, boost: Int) -> PetMood {
        let ordered: [PetMood] = [.grumpy, .sleepy, .calm, .happy, .ecstatic]
        guard let index = ordered.firstIndex(of: mood) else { return mood }
        let newIndex = min(ordered.count - 1, index + boost)
        return ordered[newIndex]
    }
}
