import Foundation
import SwiftData

enum ItemType: String, Codable, CaseIterable {
    case snack
    case toy
    case decor

    var icon: String {
        switch self {
        case .snack: return "takeoutbag.and.cup.and.straw"
        case .toy: return "puzzlepiece.extension"
        case .decor: return "paintbrush.pointed"
        }
    }
}

@Model
final class Item: Identifiable {
    @Attribute(.unique) var id: UUID
    var sku: String
    var type: ItemType
    var name: String
    var costEnergy: Int
    var moodBoost: Int
    var hungerBoost: Int

    init(
        id: UUID = UUID(),
        sku: String,
        type: ItemType,
        name: String,
        costEnergy: Int,
        moodBoost: Int,
        hungerBoost: Int
    ) {
        self.id = id
        self.sku = sku
        self.type = type
        self.name = name
        self.costEnergy = costEnergy
        self.moodBoost = moodBoost
        self.hungerBoost = hungerBoost
    }
}
