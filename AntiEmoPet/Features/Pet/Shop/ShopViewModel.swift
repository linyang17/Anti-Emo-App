import Foundation
import Combine

struct ShopSection: Identifiable {
    let type: ItemType
    let items: [Item]
    var id: ItemType { type }
}

@MainActor
final class ShopViewModel: ObservableObject {
    func grouped(items: [Item]) -> [ShopSection] {
        ItemType.allCases.compactMap { type in
            let filtered = items.filter { $0.type == type }
            return filtered.isEmpty ? nil : ShopSection(type: type, items: filtered)
        }
    }
}
