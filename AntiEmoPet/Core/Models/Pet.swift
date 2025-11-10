import Foundation
import SwiftData

enum PetMood: String, Codable, CaseIterable {
    case ecstatic, happy, calm, sleepy, anxious, grumpy

    var displayName: String {
        switch self {
        case .ecstatic: return "活力满满"
        case .happy: return "开始摇尾巴"
        case .calm: return "有点无聊"
        case .sleepy: return "困困"
        case .anxious: return "开始焦虑"
        case .grumpy: return "好想好想你"
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
        mood: PetMood = .calm,
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
