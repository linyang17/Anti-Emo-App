import Foundation

// Compatibility layer to bridge older code that used `count` with the newer `quantity` API
extension InventoryEntry {
    // Provide a `count` computed property mapping to `quantity`
    var count: Int {
        get { return self.quantity }
        set { self.quantity = newValue }
    }

    // Convenience initializer to support older call sites: InventoryEntry(sku:count:)
    convenience init(sku: String, count: Int) {
        self.init(sku: sku, name: sku, type: .snack, quantity: count)
    }
}
