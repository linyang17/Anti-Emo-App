import Foundation

@MainActor
final class RewardEngine {
    func applyTaskReward(for task: Task, stats: UserStats) -> Int {
        guard task.status == .completed else { return 0 }
        let energy = task.difficulty.energyReward
        stats.totalEnergy += energy
        stats.coins += 5
        stats.completedTasksCount += 1
        stats.lastActiveDate = .now
        return energy
    }

    func evaluateAllClear(tasks: [Task], stats: UserStats) -> Bool {
        guard tasks.allSatisfy({ $0.status == .completed }) else { return false }
        stats.streakDays += 1
        return true
    }

    func purchase(item: Item, stats: UserStats) -> Bool {
        guard stats.totalEnergy >= item.costEnergy else { return false }
        stats.totalEnergy -= item.costEnergy
        stats.coins = max(0, stats.coins - 2)
        stats.lastActiveDate = .now
        return true
    }
}
