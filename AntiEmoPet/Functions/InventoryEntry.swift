import Foundation
import SwiftData

@Model
final class InventoryEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var sku: String
    var quantity: Int

    init(id: UUID = UUID(), sku: String, quantity: Int = 0) {
        self.id = id
        self.sku = sku
        self.quantity = quantity
    }

    var count: Int {
        get { quantity }
        set { quantity = newValue }
    }

    convenience init(sku: String, count: Int) {
        self.init(sku: sku, quantity: count)
    }
}
