import Foundation
import SwiftData
import Combine
import SwiftUI

// MARK: - Item Type (Stable, Type-Safe Enum)

enum ItemType: String, Codable, CaseIterable, Sendable {
	case decor
	case clothing
	case shoes
	case snack

	static var allCases: [ItemType] { [.snack, .decor, .clothing, .shoes] }

	var icon: String {
		switch self {
		case .decor: "paintbrush.pointed"
		case .clothing: "tshirt.fill"
		case .shoes: "shoeprints.fill"
		case .snack: "takeoutbag.and.cup.and.straw"
		}
	}

	var displayName: String {
		switch self {
		case .decor: "Decor"
		case .clothing: "Clothing"
		case .shoes: "Shoes"
		case .snack: "Snacks"
		}
	}
}

// MARK: - SwiftData Model

@Model
final class Item: Identifiable {

	var sku: String
	var type: ItemType
	var assetName: String
	var costEnergy: Int
	var bondingBoost: Int

	enum CodingKeys: String, CodingKey {
		case sku, type, assetName, costEnergy, bondingBoost
	}

	init(
		sku: String,
		type: ItemType,
		assetName: String = "",
		costEnergy: Int,
		bondingBoost: Int
	) {
		self.sku = sku
		self.type = type
		self.assetName = assetName
		self.costEnergy = costEnergy
		self.bondingBoost = bondingBoost
	}
}

// MARK: - Computed Properties (UI + Logic Layer)
extension Item {
	nonisolated var isConsumable: Bool { type == .snack }
}

// MARK: - JSON Seed Structures

private struct ItemSeedContainer: Decodable {
	let version: Int
	let items: [ItemSeed]
}

private struct ItemSeed: Decodable {
	let sku: String
	let type: String
	let assetName: String
	let costEnergy: Int
	let bondingBoost: Int
}

// MARK: - Item Loader (SwiftData + Versioned JSON)

@MainActor
final class ItemLoader: ObservableObject, Sendable {

	static let shared = ItemLoader()

	@AppStorage("ItemDataVersion") private var lastLoadedVersion: Int = 0
	@Published private(set) var items: [Item] = []

	private init(bundle: Bundle = .main) {
		Task { await load(bundle: bundle) }
	}

	// MARK: - 主加载逻辑
	private func load(bundle: Bundle) async {
		do {
			guard let container = try? ModelContainer(for: Item.self) else {
				print("❌ SwiftData ModelContainer not initialized.")
				return
			}

			let context = container.mainContext

			// 优先从数据库读取
			let dbItems = loadFromDatabase(context: context)
			if !dbItems.isEmpty {
				self.items = dbItems
				print("✅ Loaded \(dbItems.count) items from SwiftData cache.")
			}

			// 检查 JSON 版本
			let (jsonVersion, jsonItems) = loadItemFromJSON(bundle: bundle)
			if jsonVersion > lastLoadedVersion {
				print("🔄 Detected new item data version \(jsonVersion)")
				lastLoadedVersion = jsonVersion
				self.items = jsonItems

				// 清除旧缓存 & 写入新数据
				clearDatabase(context)
				saveToDatabase(jsonItems, context: context)
				print("✅ Updated \(jsonItems.count) items in SwiftData.")
			} else if dbItems.isEmpty {
				self.items = jsonItems
				saveToDatabase(jsonItems, context: context)
				print("✅ Cached \(jsonItems.count) items into SwiftData.")
			} else {
				print("✅ Items up to date (version \(jsonVersion)).")
			}
		}
	}

	// MARK: - JSON 加载
	private func loadItemFromJSON(bundle: Bundle) -> (version: Int, items: [Item]) {
		guard
			let url = bundle.url(forResource: "items", withExtension: "json"),
			let data = try? Data(contentsOf: url)
		else {
			print("❌ items.json not found in bundle")
			return (version: lastLoadedVersion, [])
		}

		do {
			let decoded = try JSONDecoder().decode(ItemSeedContainer.self, from: data)
			let version = decoded.version
			let items = decoded.items.compactMap { seed -> Item? in
				guard let type = ItemType(rawValue: seed.type.lowercased()) else { return nil }
				return Item(
					sku: seed.sku,
					type: type,
					assetName: seed.assetName,
					costEnergy: seed.costEnergy,
					bondingBoost: seed.bondingBoost
				)
			}
			return (version, items)
		} catch {
			print("❌ Failed to decode items.json: \(error.localizedDescription)")
			return (version: lastLoadedVersion, [])
		}
	}

	// MARK: - SwiftData 读写
	private func loadFromDatabase(context: ModelContext) -> [Item] {
		do { return try context.fetch(FetchDescriptor<Item>()) }
		catch {
			print("⚠️ SwiftData fetch failed: \(error)")
			return []
		}
	}

	private func saveToDatabase(_ items: [Item], context: ModelContext) {
		for item in items { context.insert(item) }
		do { try context.save() }
		catch { print("⚠️ SwiftData save failed: \(error)") }
	}

	private func clearDatabase(_ context: ModelContext) {
		do {
			let all = try context.fetch(FetchDescriptor<Item>())
			all.forEach { context.delete($0) }
			try context.save()
			print("🧹 Cleared old item cache.")
		} catch {
			print("⚠️ Failed to clear old items: \(error)")
		}
	}

	// MARK: - Public Access
	func allItems(of type: ItemType? = nil) -> [Item] {
		guard let type else { return items }
		return items.filter { $0.type == type }
	}

	func item(withSKU sku: String) -> Item? {
		items.first { $0.sku == sku }
	}

	func randomItem(of type: ItemType? = nil) -> Item? {
		let filtered = allItems(of: type)
		return filtered.randomElement()
	}
}
