import SwiftUI
import Charts

struct AdvancedInsightsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	
	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				// Mood vs Energy Correlation
				DashboardCard(title: "Mood & Energy Correlation", icon: "arrow.triangle.2.circlepath") {
					MoodEnergyCorrelationChart()
				}
				
				// Mood Delta by Task Category
				DashboardCard(title: "Task Impact on Mood", icon: "chart.bar.xaxis") {
					TaskMoodImpactChart()
				}
				
				// Weather Impact
				DashboardCard(title: "Weather & Activity Pattern", icon: "cloud.sun") {
					//WeatherActivityChart()
				}
			}
			.padding()
		}
		.navigationTitle("Advanced Insights")
	}
}

private struct MoodEnergyCorrelationChart: View {
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

private struct TaskMoodImpactChart: View {
	@EnvironmentObject private var appModel: AppViewModel
	
	var body: some View {
		let data = taskImpactData()
		if data.isEmpty {
			Text("Complete tasks and log mood after to see impact").foregroundStyle(.secondary)
		} else {
			Chart(data) { point in
				BarMark(x: .value("Category", point.category.rawValue), y: .value("Avg Delta", point.avgDelta))
					.foregroundStyle(point.avgDelta > 0 ? .green : .red)
			}
			.frame(height: 200)
		}
	}
	
	private func taskImpactData() -> [TaskImpact] {
		// Provide explicit type to resolve '.afterTask' without contextual type error
		let entryStatus: MoodEntry.MoodSource = .afterTask
		let afterTaskEntries = appModel.moodEntries.filter {
			$0.source == entryStatus.rawValue
		}
		var categoryDeltas: [TaskCategory: [Int]] = [:]
		
		for entry in afterTaskEntries {
			if let category = entry.relatedTaskCategory, let delta = entry.delta {
				categoryDeltas[
					TaskCategory(rawValue: category)!,
					default: []
				]
					.append(delta)
			}
		}
		
		return categoryDeltas.compactMap { key, values in
			guard !values.isEmpty else { return nil }
			let avg = Double(values.reduce(0, +)) / Double(values.count)
			return TaskImpact(category: key, avgDelta: avg)
		}.sorted { $0.avgDelta > $1.avgDelta }
	}
}

private struct WeatherActivityChart: View {
	@EnvironmentObject private var appModel: AppViewModel
	
	var body: some View {
		let data = weatherActivityData()
		if data.isEmpty {
			Text("Track more activities to see weather patterns").foregroundStyle(.secondary)
		} else {
			Chart(data) { point in
				BarMark(x: .value("Weather", point.weather.rawValue), y: .value("Tasks", point.taskCount))
					.foregroundStyle(.blue)
			}
			.frame(height: 200)
		}
	}
	
	private func weatherActivityData() -> [WeatherTaskActivity] {
		var weatherCounts: [WeatherType: [String: Int]] = [:]
		
		for task in appModel.tasksSince(days: 365) where task.status == .completed {
			weatherCounts[task.weatherType, default: [:]][task.category.rawValue, default: 0] += 1
		}
		
		return weatherCounts
			.map {
				WeatherTaskActivity(
					weather: $0.self.key,
					category: TaskCategory(rawValue: $0.key.rawValue)!,
					taskCount: $0.value.values.reduce(0, +)
				)
			}
			.sorted { $0.taskCount > $1.taskCount }
	}
}

private struct CorrelationPoint: Identifiable {
	let mood: Double
	let energy: Int
	var id: String { "\(mood)-\(energy)" }
}

private struct TaskImpact: Identifiable {
	let category: TaskCategory
	let avgDelta: Double
	var id: String { category.rawValue }
}

private struct WeatherTaskActivity: Identifiable {
	let weather: WeatherType
	let category: TaskCategory
	let taskCount: Int
	var id: String { weather.rawValue }
}

