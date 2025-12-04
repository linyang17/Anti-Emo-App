import SwiftUI
import Charts
import Combine

struct StatsRhythmSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var analysis = AnalysisViewModel()
	@StateObject private var slotAnimator = AnimatedChartData<SlotAverage>()
	@StateObject private var weatherAnimator = AnimatedChartData<WeatherAverage>()
	@StateObject private var daylightAnimator = AnimatedChartData<DaylightAverage>()
	@StateObject private var daylightLineAnimator = AnimatedChartData<DaylightDurationAverage>()
	@StateObject private var taskImpactAnimator = AnimatedChartData<TaskImpact>()

	// 缓存数据，避免重复计算
	@State private var cachedSlotData: [SlotAverage] = []
	@State private var cachedWeatherData: [WeatherAverage] = []
	@State private var cachedDaylightData: [DaylightAverage] = []
	@State private var cachedDaylightLineData: [DaylightDurationAverage] = []
	@State private var cachedTaskImpactData: [TaskImpact] = []

	var body: some View {
		VStack(spacing: 16) {

            DashboardCard(title: "Mood vs Timeslot", icon: "deskclock") {
                MoodHeatmapView(data: analysis.heatmapData)
            }

			DashboardCard(title: "Mood vs Weather", icon: "cloud.sun") {
				rhythmWeatherChart(data: analysis.weatherAverages)
			}

			DashboardCard(title: "Mood vs Daylight", icon: "sun.horizon.fill") {
				rhythmDaylightLineChart(data: analysis.daylightLengthData)
			}
			
			DashboardCard(title: "Task Impact", icon: "theatermasks.fill") {
				TaskMoodImpactChart(data: analysis.taskImpactAverages)
			}
			
		}
		.onAppear {
			if !appModel.isLoading {
				refreshRhythms()
			}
		}
	}

	private func refreshRhythms() {
		guard !appModel.isLoading else { return }
		
		Task(priority: .userInitiated) {
			analysis.rhythmAnalysis(for: appModel.moodEntries, dayLength: appModel.sunEvents)
		}
	}


	// MARK: - 天气图
	@ViewBuilder
	private func rhythmWeatherChart(data: [WeatherType: Double]) -> some View {
		if data.isEmpty {
			rhythmPlaceholder(systemImage: "cloud.sun")
		} else {
			let theme = ChartTheme.shared
			Chart(weatherAnimator.displayData) { item in
				BarMark(
					x: .value("Weather", item.type.rawValue),
					y: .value("Mood", item.value)
				)
				.foregroundStyle(theme.gradient(for: item.type))
				.cornerRadius(6)
			}
			.chartXAxis { AxisMarks(position: .bottom, values: .automatic) { _ in
				AxisGridLine()
				AxisTick()
				AxisValueLabel(centered: true)
			} }
			.chartYAxis { AxisMarks(position: .leading) }
			.frame(height: 200)
			.task(id: data) {
				await updateWeatherData(data)
			}
		}
	}


	// MARK: - 日照时长折线图
	@ViewBuilder
	private func rhythmDaylightLineChart(data: [Int: Double]) -> some View {
		if data.isEmpty {
			rhythmPlaceholder(systemImage: "sun.max")
		} else {
			let hoursValues = data.keys.sorted()  // currently in minutes
			// 自动范围 + buffer（左右各留 1 小时）
			let minX = max(0, (hoursValues.min() ?? 0) - 60)
			let maxX = min(1500, (hoursValues.max() ?? 0) + 60)
			
			Chart(daylightLineAnimator.displayData) { item in
				LineMark(
					x: .value("Day Length", item.hours),
					y: .value("Mood", item.value)
				)
				.interpolationMethod(.catmullRom)
				.symbol(.circle)
				.foregroundStyle(Color.orange)
			}
			.chartXScale(domain: minX...maxX)
			.chartXAxis {
				AxisMarks(position: .bottom, values: .stride(by: 30)) { value in
					if let minutes = value.as(Int.self) {
						let h = minutes / 60
						let m = minutes % 60
						let label = m == 0 ? "\(h)h" : "\(h)h\(m)m"
						AxisGridLine()
						AxisTick()
						AxisValueLabel {
							Text(label)
								.font(.caption)
								.frame(maxWidth: .infinity, alignment: .center) // 水平居中
						}
					}
				}
			}
			.chartYAxis {
				AxisMarks(position: .leading) { value in
					if let mood = value.as(Double.self) {
						AxisGridLine()
						AxisTick()
						AxisValueLabel(String(format: "%.0f", mood))
					}
				}
			}
			.frame(height: 200)
			.task(id: data) {
				await updateDaylightLineData(data)
			}
		}
	}
	
	// MARK: - 任务效果图
	@ViewBuilder
	private func TaskMoodImpactChart(data: [TaskCategory: Double]) -> some View {
		if data.isEmpty {
			rhythmPlaceholder(systemImage: "checkmark.circle")
		} else {
			let theme = ChartTheme.shared
			Chart(taskImpactAnimator.displayData) { item in
				BarMark(
                                    x: .value("Task Category", item.category.localizedTitle),
					y: .value("Avg Mood Change", item.avgDelta)
				)
				.foregroundStyle(theme.gradient(for: item.category))
				.cornerRadius(6)
			}
			.chartXAxis {
				AxisMarks(position: .bottom, values: .automatic) { value in
					AxisGridLine()
					AxisTick()
					AxisValueLabel {
						if let label = value.as(String.self) {
							Text(label)
								.font(.caption2)
								.multilineTextAlignment(.center)
								.lineLimit(nil)
								.fixedSize(horizontal: false, vertical: true)
								.frame(width: 55)
						}
					}
				}
			}
			.chartYAxis {
				AxisMarks(position: .leading) { value in
					if let delta = value.as(Double.self) {
						AxisGridLine()
						AxisTick()
						AxisValueLabel(String(format: "%.0f", delta))
					}
				}
			}
			.frame(height: 200)
			.task(id: data) {
				await updateTaskImpactData(data)
			}
		}
	}

	
	// MARK: - 异步更新逻辑

	@MainActor
	private func updateSlotData(_ data: [TimeSlot: Double]) async {
		let computed = TimeSlot.allCases.lazy.compactMap { slot -> SlotAverage? in
			guard let value = data[slot] else { return nil }
			return SlotAverage(slot: slot, value: value)
		}
		cachedSlotData = Array(computed)
		slotAnimator.update(with: cachedSlotData)
	}

	@MainActor
	private func updateWeatherData(_ data: [WeatherType: Double]) async {
		let computed = WeatherType.allCases.lazy.compactMap { type -> WeatherAverage? in
			guard let value = data[type] else { return nil }
			return WeatherAverage(type: type, value: value)
		}
		// 降采样，最多渲染 1000 条
		let reduced = Array(computed.prefix(1000))
		cachedWeatherData = reduced
		weatherAnimator.update(with: reduced)
	}
	

	@MainActor
	private func updateDaylightData(_ buckets: [DayPeriod: Double]) async {
		let computed = DayPeriod.allCases.lazy.compactMap { period -> DaylightAverage? in
			guard let value = buckets[period] else { return nil }
			return DaylightAverage(period: period, value: value)
		}
		cachedDaylightData = Array(computed)
		daylightAnimator.update(with: cachedDaylightData)
	}

	@MainActor
	private func updateDaylightLineData(_ data: [Int: Double]) async {
		let computed = data.keys.sorted().map { hours -> DaylightDurationAverage in
			DaylightDurationAverage(hours: hours, value: data[hours] ?? 0)
		}
		// Force refresh by assigning a new array even if content is similar, to trigger chart update
		cachedDaylightLineData = [] 
		try? await Task.sleep(nanoseconds: 10_000_000)
		cachedDaylightLineData = computed
		daylightLineAnimator.update(with: computed)
	}
	
	@MainActor
	private func updateTaskImpactData(_ data: [TaskCategory: Double]) async {
		let computed = TaskCategory.allCases.lazy.compactMap { category -> TaskImpact? in
			guard let value = data[category] else { return nil }
			return TaskImpact(category: category, avgDelta: value)
		}
		cachedTaskImpactData = Array(computed)
		taskImpactAnimator.update(with: cachedTaskImpactData)
	}

	// MARK: - Placeholder
	@ViewBuilder
	private func rhythmPlaceholder(systemImage: String) -> some View {
		VStack(spacing: 12) {
			Image(systemName: systemImage)
			.font(.system(size: 28))
			.foregroundStyle(.secondary)
			Text("No Data")
			.font(.footnote)
			.foregroundStyle(.secondary)
			Text("Unlock when you have more mood records.")
			.font(.caption2)
			.foregroundStyle(.secondary)
		}
		.multilineTextAlignment(.center)
		.frame(maxWidth: .infinity, minHeight: 120)
	}
}

// MARK: - Data Models
private struct SlotAverage: Identifiable, Equatable {
	let slot: TimeSlot
	let value: Double
	var id: String { slot.rawValue }
}

private struct WeatherAverage: Identifiable, Equatable {
	let type: WeatherType
	let value: Double
	var id: String { type.rawValue }
}

private struct DaylightAverage: Identifiable, Equatable {
	let period: DayPeriod
	let value: Double
	var id: String { period.rawValue }
}

private struct DaylightDurationAverage: Identifiable, Equatable {
	let hours: Int
	let value: Double
	var id: Int { hours }
}

private struct TaskImpact: Identifiable, Equatable {
	   let category: TaskCategory
	   let avgDelta: Double
	   var id: String { category.rawValue }
   }

