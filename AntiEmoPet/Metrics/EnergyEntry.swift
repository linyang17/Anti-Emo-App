import Foundation
import SwiftData
import SwiftUI


@Model
final class EnergyHistoryEntry: Identifiable, Codable {
	@Attribute(.unique) var id: UUID
	var date: Date
	var totalEnergy: Int

	init(id: UUID = UUID(), date: Date = .now, totalEnergy: Int) {
		self.id = id
		self.date = date
		self.totalEnergy = totalEnergy
	}
	
	private enum CodingKeys: String, CodingKey {
		case id
		case date
		case totalEnergy
	}
	
	
	convenience init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let id = try container.decode(UUID.self, forKey: .id)
		let date = try container.decode(Date.self, forKey: .date)
		let totalEnergy = try container.decode(Int.self, forKey: .totalEnergy)
		self.init(
			id: id,
			date: date,
			totalEnergy: totalEnergy
		)
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(id, forKey: .id)
		try container.encode(date, forKey: .date)
		try container.encode(totalEnergy, forKey: .totalEnergy)
	}
	
}


struct EnergyEngine {
	@EnvironmentObject private var appModel: AppViewModel
	
    static func add(_ amount: Int, to stats: UserStats) {
        stats.totalEnergy = clamp(stats.totalEnergy + amount)
        stats.lastActiveDate = .now
    }

    static func spend(_ amount: Int, from stats: UserStats) -> Bool {
        guard stats.totalEnergy >= amount else { return false }
        stats.totalEnergy = clamp(stats.totalEnergy - amount)
        stats.lastActiveDate = .now
        return true
    }

    static func clamp(_ value: Int) -> Int {
        return max(0, min(999, value))
    }

}

