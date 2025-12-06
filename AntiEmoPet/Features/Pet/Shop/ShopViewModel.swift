import Foundation
import Combine

@MainActor
final class ShopViewModel: ObservableObject {
    let gridCapacity = 6

    func availableCategories(in items: [Item]) -> [ItemType] {
        let types = Set(items.map(\.type))
        let ordered = ItemType.allCases.filter { $0 != .snack }
        let filtered = ordered.filter { types.contains($0) }
        return filtered.isEmpty ? ordered : filtered
    }

    func items(for type: ItemType, in items: [Item]) -> [Item] {
        items.filter { $0.type == type }
    }

    func placeholderCount(for items: [Item]) -> Int {
        max(0, 3 - items.count)
    }

    func defaultCategory(in items: [Item]) -> ItemType {
        if let first = items.first?.type {
            return first
        }
        return ItemType.allCases.first ?? .decor
    }
}
