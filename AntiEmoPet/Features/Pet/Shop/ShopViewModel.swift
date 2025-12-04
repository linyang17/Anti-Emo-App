import Foundation
import Combine

@MainActor
final class ShopViewModel: ObservableObject {
    let gridCapacity = 100 // Show all items (effectively no limit for MVP)

    func availableCategories(in items: [Item]) -> [ItemType] {
        let types = Set(items.map(\.type))
        let ordered = ItemType.allCases.filter { $0 != .snack }
        let filtered = ordered.filter { types.contains($0) }
        return filtered.isEmpty ? ordered : filtered
    }

    func items(for type: ItemType, in items: [Item], limit: Int) -> [Item] {
        let filtered = items.filter { $0.type == type }
        guard limit < filtered.count else { return filtered }
        return Array(filtered.prefix(limit))
    }

    func defaultCategory(in items: [Item]) -> ItemType {
        if let first = items.first?.type {
            return first
        }
        return ItemType.allCases.first ?? .decor
    }
}
