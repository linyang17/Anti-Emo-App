import Foundation
import SwiftData

enum ItemType: String, Codable, CaseIterable {
    case decor
    case clothing
    case shoes
    case snack
    case toy

    static var allCases: [ItemType] { [.decor, .clothing, .shoes] }

    var icon: String {
        switch self {
        case .decor: return "paintbrush.pointed"
        case .clothing: return "tshirt.fill"
        case .shoes: return "shoeprints.fill"
        case .snack: return "takeoutbag.and.cup.and.straw"
        case .toy: return "puzzlepiece.extension"
        }
    }

    var displayName: String {
        switch self {
        case .decor: return "Decor"
        case .clothing: return "Clothing"
        case .shoes: return "Shoes"
        case .snack: return "Snack"
        case .toy: return "Toy"
        }
    }
}

@Model
final class Item: Identifiable {
    @Attribute(.unique) var id: UUID
    var sku: String
    var type: ItemType
    var name: String
    var assetName: String
    var costEnergy: Int
    var BondingBoost: Int
    var hungerBoost: Int

    init(
        id: UUID = UUID(),
        sku: String,
        type: ItemType,
        name: String,
        assetName: String = "",
        costEnergy: Int,
        BondingBoost: Int,
        hungerBoost: Int
    ) {
        self.id = id
        self.sku = sku
        self.type = type
        self.name = name
        self.assetName = assetName
        self.costEnergy = costEnergy
        self.BondingBoost = BondingBoost
        self.hungerBoost = hungerBoost
    }
}
