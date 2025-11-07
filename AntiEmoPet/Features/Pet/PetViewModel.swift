import Foundation
import Combine

@MainActor
final class PetViewModel: ObservableObject {
    func moodDescription(for pet: Pet) -> String {
        "Sunny 现在\(pet.mood.displayName)，多陪陪它吧"
    }
}
