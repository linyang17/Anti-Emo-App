import SwiftUI
import Charts

struct AdvancedInsightsView: View {
	@EnvironmentObject private var appModel: AppViewModel
	
	var body: some View {
		ScrollView {
			VStack(spacing: 20) {
				// Mood vs Energy Correlation
				DashboardCard(title: "Activity Pattern", icon: "arrow.2.squarepath") {
					MoodEnergyCorrelationChart()
				}
			}
			.padding()
		}
		.navigationTitle("Advanced Insights")
	}
}

private struct MoodEnergyCorrelationChart: View {
	@EnvironmentObject private var appModel: AppViewModel
	@State private var selectedWeather: WeatherType?
	
	var body: some View {
		VStack {
			// Weather Filter
			ScrollView(.horizontal, showsIndicators: false) {
				HStack {
					FilterChip(title: "All", isSelected: selectedWeather == nil) {
						selectedWeather = nil
					}
					ForEach(WeatherType.allCases) { weather in
						FilterChip(title: weather.rawValue.capitalized, isSelected: selectedWeather == weather) {
							selectedWeather = weather
						}
					}
				}
				.padding(.bottom, 8)
			}
			
			let data = correlationData()
			if data.isEmpty {
				Text("Need more data for correlation analysis").foregroundStyle(.secondary)
			} else {
				Chart(data) { point in
					PointMark(x: .value("Energy", point.energy), y: .value("Mood", point.mood))
						.foregroundStyle(point.category.color)
                                             .symbol(by: .value("Category", point.category.localizedTitle))
				}
				.chartForegroundStyleScale([
					"Outdoor Activities": .green,
					"Digital": .purple,
					"Indoor Activities": .orange,
					"Physical Exercises": .red,
					"Social Interactions": .blue,
					"Pet Care": .brown
				])
				.frame(height: 220)
			}
		}
	}
	
	private func correlationData() -> [CorrelationPoint] {
		// Only tasks that have a linked mood entry
		let tasksWithMood = appModel.tasksSince(days: 90).filter { 
			$0.status == .completed && $0.moodEntryId != nil && (selectedWeather == nil || $0.weatherType == selectedWeather)
		}
		
		return tasksWithMood.compactMap { task in
			guard let moodId = task.moodEntryId,
				  let moodEntry = appModel.moodEntries.first(where: { $0.id == moodId }) else { return nil }
			
			return CorrelationPoint(
				mood: Double(moodEntry.value),
				energy: task.energyReward,
				category: task.category
			)
		}
	}
}

private struct FilterChip: View {
	let title: String
	let isSelected: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			Text(title)
				.font(.caption.weight(.medium))
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(isSelected ? Color.blue : Color.gray.opacity(0.1), in: Capsule())
				.foregroundStyle(isSelected ? .white : .primary)
		}
	}
}

private struct CorrelationPoint: Identifiable {
	let mood: Double
	let energy: Int
	let category: TaskCategory
	var id: String { "\(mood)-\(energy)-\(category.rawValue)" }
}

extension TaskCategory {
	var color: Color {
		switch self {
		case .outdoor: return .green
		case .indoorDigital: return .purple
		case .indoorActivity: return .orange
		case .physical: return .red
		case .socials: return .blue
		case .petCare: return .brown
		}
	}
}

