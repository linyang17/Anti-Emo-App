import Foundation

@MainActor
final class RewardEngine {
    func applyTaskReward(for task: UserTask, stats: UserStats) -> Int {
        guard task.status == .completed else { return 0 }
        let energy = max(0, task.energyReward)
        EnergyEngine.add(energy, to: stats)
        stats.completedTasksCount += 1
        stats.lastActiveDate = .now
        return energy
    }

		/// Returns a random snack item from the provided catalog.
		/// Keeping the logic inside RewardEngine allows future reuse for
		/// commemorative drops or probability tuning.
		func randomSnackReward(from items: [Item]) -> Item? {
			let snacks = items.filter { $0.type == .snack }
			return snacks.randomElement()
		}

    func evaluateAllClear(tasks: [UserTask], stats: UserStats) -> Bool {
        guard tasks.allSatisfy({ $0.status == .completed }) else { return false }
        stats.TotalDays += 1
        return true
    }

    func purchase(item: Item, stats: UserStats) -> Bool {
        guard EnergyEngine.spend(item.costEnergy, from: stats) else { return false }
		stats.totalEnergy -= item.costEnergy
        stats.lastActiveDate = .now
        return true
    }
}
