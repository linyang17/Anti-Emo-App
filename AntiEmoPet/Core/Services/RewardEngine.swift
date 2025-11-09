import Foundation

@MainActor
final class RewardEngine {
    func applyTaskReward(for task: Task, stats: UserStats) -> Int {
        guard task.status == .completed else { return 0 }
        let energy = task.difficulty.energyReward
        EnergyEngine.add(energy, to: stats)
        stats.coins += 5
        stats.completedTasksCount += 1
        stats.lastActiveDate = .now
        return energy
    }

    func evaluateAllClear(tasks: [Task], stats: UserStats) -> Bool {
        guard tasks.allSatisfy({ $0.status == .completed }) else { return false }
        stats.TotalDays += 1
        return true
    }

    func purchase(item: Item, stats: UserStats) -> Bool {
        guard EnergyEngine.spend(item.costEnergy, from: stats) else { return false }
        stats.coins = max(0, stats.coins - 2)
        stats.lastActiveDate = .now
        return true
    }
}
