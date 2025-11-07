import Foundation
import SwiftData

@Model
final class MoodEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var value: Int // 0-100

    init(id: UUID = UUID(), date: Date = .now, value: Int) {
        self.id = id
        self.date = date
        self.value = value
    }
}
