import Foundation
import SwiftData

enum PetBonding: String, Codable, CaseIterable {
    case ecstatic, happy, calm, sleepy, anxious

    var displayName: String {
        switch self {
        case .ecstatic: return "活力满满"
        case .happy: return "开始摇尾巴"
        case .calm: return "有点无聊"
        case .sleepy: return "困困"
        case .anxious: return "好想好想你"
        }
    }
}

@Model
final class Pet: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var bonding: PetBonding
    var hunger: Int
    var level: Int
    var xp: Int
    var decorations: [String]

    init(
        id: UUID = UUID(),
        name: String,
        bonding: PetBonding = .calm,
        hunger: Int = 60,
        level: Int = 1,
        xp: Int = 0,
        decorations: [String] = []
    ) {
        self.id = id
        self.name = name
        self.bonding = bonding
        self.hunger = hunger
        self.level = level
        self.xp = xp
        self.decorations = decorations
    }
}
