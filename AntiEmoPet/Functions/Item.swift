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


enum StaticItemLoader {
	
	private struct ItemDefinition: Decodable {
		let id: UUID?
		let sku: String
		let type: ItemType
		let assetName: String?
		let costEnergy: Int
		let bondingBoost: Int?

		enum CodingKeys: String, CodingKey {
			case id
			case sku
			case type
			case assetName
			case costEnergy
			case bondingBoost = "bondingBoost"
		}

		func makeItem() -> Item {
			Item(
				id: id ?? UUID(),
				sku: sku,
				type: type,
				assetName: assetName ?? "",
				costEnergy: costEnergy,
				BondingBoost: bondingBoost ?? 0
			)
		}
	}

	static func loadAllItems() -> [Item] {
		guard
			let url = Bundle.main.url(forResource: "items", withExtension: "json"),
			let data = try? Data(contentsOf: url)
		else {
			return []
		}

		do {
			let decoded = try JSONDecoder().decode([ItemDefinition].self, from: data)
			return decoded.map { $0.makeItem() }
		} catch {
			print("❌ Failed to decode items.json: \(error)")
			return []
		}
	}
}


@Model
final class Item: Identifiable {
	@Attribute(.unique) var id: UUID
	var sku: String
	var type: ItemType
	var assetName: String
	var costEnergy: Int
	var BondingBoost: Int

	init(
		id: UUID = UUID(),
		sku: String,
		type: ItemType,
		assetName: String = "",
		costEnergy: Int,
		BondingBoost: Int
	) {
		self.id = id
		self.sku = sku
		self.type = type
		self.assetName = assetName
		self.costEnergy = costEnergy
		self.BondingBoost = BondingBoost
	}
}
