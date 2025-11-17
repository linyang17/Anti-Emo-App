import SwiftUI
import Charts
import Combine

struct StatsRhythmSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	@StateObject private var analysis = AnalysisViewModel()

	@StateObject private var slotAnimator = AnimatedChartData<SlotAverage>()
	@StateObject private var weatherAnimator = AnimatedChartData<WeatherAverage>()
	@StateObject private var daylightAnimator = AnimatedChartData<DaylightAverage>()

	// 缓存数据，避免重复计算
	@State private var cachedSlotData: [SlotAverage] = []
	@State private var cachedWeatherData: [WeatherAverage] = []
	@State private var cachedDaylightData: [DaylightAverage] = []

	var body: some View {
		VStack(spacing: 16) {
			DashboardCard(title: "情绪时段分析", icon: "clock") {
				rhythmSlotChart(data: analysis.timeSlotAverages)
			}

			DashboardCard(title: "天气关联度", icon: "cloud.sun") {
				//rhythmWeatherChart(data: analysis.weatherAverages)
			}

			DashboardCard(title: "日照关联度", icon: "sun.max") {
				rhythmDaylightView(buckets: analysis.dayPeriodAverages, hint: analysis.daylightHint)
			}
		}
		.onAppear(perform: refreshRhythms)
		.onReceive(appModel.$moodEntries) { _ in refreshRhythms() }
		.onReceive(appModel.$todayTasks) { _ in refreshRhythms() }
		.onReceive(appModel.$sunEvents) { _ in refreshRhythms() }
	}

        private func refreshRhythms() {
		Task(priority: .userInitiated) {
			await analysis.rhythmAnalysis(for: appModel.moodEntries, tasks: appModel.allTasks, sunEvents: appModel.sunEvents)
		}
        }

	// MARK: - 时段图
	@ViewBuilder
	private func rhythmSlotChart(data: [TimeSlot: Double]) -> some View {
		if data.isEmpty {
			rhythmPlaceholder(systemImage: "clock")
		} else {
			let theme = ChartTheme.shared

			Chart(slotAnimator.displayData) { item in
				BarMark(
					x: .value("Timeslot", item.slot.rawValue),
					y: .value("Mood", item.value)
				)
				.foregroundStyle(theme.gradient(for: .sunny))
				.cornerRadius(6)
				.annotation(position: .trailing) {
					Text(String(format: "%.0f", item.value))
						.font(.caption2.weight(.medium))
						.foregroundColor(.white.opacity(0.85))
				}
			}
			.chartXAxis { AxisMarks(position: .bottom) }
			.chartYAxis { AxisMarks(position: .leading) }
			.frame(height: 160)
			.drawingGroup()
			.task(id: data) {
				await updateSlotData(data)
			}
		}
	}


	// MARK: TO-DO: - 日照图
	/// 日间夜间的时间应该用日出到日落区分
	
	@ViewBuilder
	private func rhythmDaylightView(buckets: [DayPeriod: Double], hint: String) -> some View {
		if buckets.isEmpty {
			VStack(alignment: .center, spacing: 8) {
				rhythmPlaceholder(systemImage: "sun.max")
				if !hint.isEmpty {
					Text(hint)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
		} else {
			let theme = ChartTheme.shared

			VStack(alignment: .leading, spacing: 12) {
				Chart(daylightAnimator.displayData) { item in
					BarMark(
						x: .value("Mood", item.value),
						y: .value("Day/Night", item.period.dayPeriodTitle)
					)
					.foregroundStyle(theme.gradient(for: .sunny))
					.cornerRadius(6)
				}
				.chartXAxis { AxisMarks(position: .bottom) }
				.chartYAxis { AxisMarks(position: .leading) }
				.frame(height: 140)
				.drawingGroup()
				.task(id: buckets) {
					await updateDaylightData(buckets)
				}

				if !hint.isEmpty {
					Text(hint)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
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
