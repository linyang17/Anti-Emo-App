import Foundation
import SwiftData

enum PetMood: String, Codable, CaseIterable {
    case ecstatic, happy, calm, sleepy, grumpy

    var displayName: String {
        switch self {
        case .ecstatic: return "超开心"
        case .happy: return "开心"
        case .calm: return "平静"
        case .sleepy: return "犯困"
        case .grumpy: return "不爽"
        }
    }
}

@Model
final class Pet: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var mood: PetMood
    var hunger: Int
    var level: Int
    var xp: Int
    var decorations: [String]

    init(
        id: UUID = UUID(),
        name: String,
        mood: PetMood = .happy,
        hunger: Int = 60,
        level: Int = 1,
        xp: Int = 0,
        decorations: [String] = []
    ) {
        self.id = id
        self.name = name
        self.mood = mood
        self.hunger = hunger
        self.level = level
        self.xp = xp
        self.decorations = decorations
    }
}
