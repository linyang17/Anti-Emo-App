struct MoodEnergyCorrelationChart: View {
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
		let cal = TimeZoneManager.shared.calendar
		var daily: [Date: (mood: [Int], energy: Int)] = [:]
		
		for entry in appModel.moodEntries {
			let day = cal.startOfDay(for: entry.date)
			daily[day, default: ([], 0)].mood.append(entry.delta ?? 0)
		}
		
		for task in appModel.tasksSince(days: 90) where task.status == .completed {
			guard let completed = task.completedAt else { continue }
			let day = cal.startOfDay(for: completed)
			daily[day]?.energy += task.energyReward
		}
		
		return daily.compactMap { key, value in
			guard !value.mood.isEmpty else { return nil }
			let avgMood = Double(value.mood.reduce(0, +)) / Double(value.mood.count)
			return CorrelationPoint(mood: avgMood, energy: value.energy)
		}
	}
}
