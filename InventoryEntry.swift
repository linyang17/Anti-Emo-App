import Foundation
import SwiftData

@Model
final class InventoryEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var sku: String
    var count: Int

    init(id: UUID = UUID(), sku: String, count: Int = 0) {
        self.id = id
        self.sku = sku
        self.count = count
    }
}
