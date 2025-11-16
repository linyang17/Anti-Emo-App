import Foundation

struct EnergyHistoryEntry: Identifiable, Codable {
	let id: UUID
	let date: Date
	var totalEnergy: Int

	init(id: UUID = UUID(), date: Date, totalEnergy: Int) {
		self.id = id
		self.date = date
		self.totalEnergy = totalEnergy
	}
}


struct EnergyEngine {
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
