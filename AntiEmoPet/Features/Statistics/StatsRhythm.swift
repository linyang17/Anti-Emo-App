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

	// 缓存数据，避免重复计算
	@State private var cachedSlotData: [SlotAverage] = []
	@State private var cachedWeatherData: [WeatherAverage] = []
	@State private var cachedDaylightData: [DaylightAverage] = []
	@State private var cachedDaylightLineData: [DaylightDurationAverage] = []

	var body: some View {
		VStack(spacing: 16) {

            DashboardCard(title: "Mood Heatmap", icon: "deskclock") {
                MoodHeatmapView(data: analysis.heatmapData)
            }

			DashboardCard(title: "Weather Correlation", icon: "cloud.sun") {
				rhythmWeatherChart(data: analysis.weatherAverages)
			}

			DashboardCard(title: "Daylight Correlation", icon: "sun.max") {
				rhythmDaylightLineChart(data: analysis.daylightLengthData)
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
			await analysis.rhythmAnalysis(for: appModel.moodEntries, sunEvents: appModel.sunEvents)
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
			let hoursValues = data.keys.sorted()
			// 自动范围 + buffer（左右各留 1 小时）
			let minX = max(0, (hoursValues.min() ?? 0) - 1)
			let maxX = min(25, (hoursValues.max() ?? 0) + 1)
			
			Chart(daylightLineAnimator.displayData) { item in
				LineMark(
					x: .value("Hours", item.hours),
					y: .value("Mood", item.value)
				)
				.interpolationMethod(.catmullRom)
				.symbol(.circle)
				.foregroundStyle(Color.orange)
			}
			.chartXScale(domain: minX...maxX)
			.chartXAxis {
				AxisMarks(position: .bottom, values: .automatic) { value in
					if let intValue = value.as(Int.self) {
						AxisGridLine()
						AxisTick()
						AxisValueLabel("\(intValue)h", centered: true)
					}
				}
			}
			.chartYAxis { AxisMarks(position: .leading) }
			.frame(height: 200)
			.task(id: data) {
				await updateDaylightLineData(data)
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
