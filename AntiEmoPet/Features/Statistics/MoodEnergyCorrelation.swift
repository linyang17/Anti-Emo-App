import SwiftUI
import Charts


struct MoodEnergyCorrelation: View {
	@EnvironmentObject private var appModel: AppViewModel
	
	var body: some View {
		let data = correlationData()
		if data.isEmpty {
			Text("Need more data for correlation analysis").foregroundStyle(.secondary)
		} else {
			Chart(data) { point in
				PointMark(x: .value("Energy", point.energy), y: .value("Mood", point.mood))
					.foregroundStyle(.blue.opacity(0.6))
			}
			.frame(height: 200)
		}
	}
	
	private func correlationData() -> [CorrelationPoint] {
		let completedTasks = appModel.tasksSince(days: 90)
			.filter { $0.status == .completed }

		let afterTaskEntries = appModel.moodEntries.filter {
			$0.source == MoodEntry.MoodSource.afterTask.rawValue
		}

		var points: [CorrelationPoint] = []

		for task in completedTasks {
			let energy = task.energyReward
			let category = task.category

			// 找出所有与该任务相关的 afterTask mood 记录
			let relatedMoods = afterTaskEntries.filter { $0.id == task.id }
			guard !relatedMoods.isEmpty else { continue }

			points.append(
				CorrelationPoint(
					mood: Double(relatedMoods.count),
					energy: Double(energy),
					category: category
				)
			)
		}

		return points
	}
	
}

private struct CorrelationPoint: Identifiable {
	let mood: Double
	let energy: Double
	let category: TaskCategory
	var id: UUID = UUID()
}
