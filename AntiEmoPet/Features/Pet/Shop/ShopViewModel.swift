import Foundation
import Combine

@MainActor
final class ShopViewModel: ObservableObject {
    let gridCapacity = 6

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
