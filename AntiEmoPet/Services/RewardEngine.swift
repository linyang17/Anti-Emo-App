import Foundation

@MainActor
final class RewardEngine {
    struct TaskRewardResult {
        let energy: Int
        let snack: Item?
    }

    func energyReward(for category: TaskCategory) -> Int {
        switch category {
        case .outdoor: return 15
        case .indoorDigital: return 5
        case .indoorActivity: return 10
        case .physical: return 15
        case .socials: return 10
        case .petCare: return 5
        }
    }

    func applyTaskReward(for task: UserTask, stats: UserStats, catalog: [Item]) -> TaskRewardResult {
        guard task.status == .completed else { return .init(energy: 0, snack: nil) }
        let energy = energyReward(for: task.category)
        task.energyReward = energy
        EnergyEngine.add(energy, to: stats)
        stats.completedTasksCount += 1
        stats.lastActiveDate = .now

        let snack = randomSnackReward(from: catalog)
        return TaskRewardResult(energy: energy, snack: snack)
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
        stats.lastActiveDate = .now
        return true
    }
}
