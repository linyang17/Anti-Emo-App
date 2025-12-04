import Foundation
import SwiftData

@Model
final class EnergyEvent: Identifiable, Codable {
        @Attribute(.unique) var id: UUID
        var date: Date
        var delta: Int
        var relatedTaskId: UUID?

        init(id: UUID = UUID(), date: Date = .now, delta: Int, relatedTaskId: UUID?) {
                self.id = id
                self.date = date
                self.delta = max(0, delta)
                self.relatedTaskId = relatedTaskId
        }

        private enum CodingKeys: String, CodingKey {
                case id
                case date
                case delta
                case relatedTaskId
        }

        convenience init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let id = try container.decode(UUID.self, forKey: .id)
                let date = try container.decode(Date.self, forKey: .date)
                let delta = try container.decode(Int.self, forKey: .delta)
                let relatedTaskId = try container.decodeIfPresent(UUID.self, forKey: .relatedTaskId)
                self.init(id: id, date: date, delta: delta, relatedTaskId: relatedTaskId)
        }

        func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(id, forKey: .id)
                try container.encode(date, forKey: .date)
                try container.encode(delta, forKey: .delta)
                try container.encodeIfPresent(relatedTaskId, forKey: .relatedTaskId)
        }
}
