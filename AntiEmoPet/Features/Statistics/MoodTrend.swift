import SwiftUI
import Charts

struct MoodTrendSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	@State private var window: Int = 7

	var body: some View {
		DashboardCard(title: "情绪趋势", icon: "chart.line.uptrend.xyaxis") {
			VStack(alignment: .leading, spacing: 12) {
				Picker("窗口", selection: $window) {
					Text("日").tag(1)
					Text("周").tag(7)
					Text("月").tag(30)
					Text("季").tag(90)
				}
				.pickerStyle(.segmented)

				let data = moodAverages(windowDays: window)

				if data.isEmpty {
					ContentUnavailableView(
						"暂无数据",
						systemImage: "chart.line.uptrend.xyaxis",
						description: Text("记录更多情绪后解锁")
					)
					.frame(height: 200)
					.frame(maxWidth: .infinity)
				} else {
					Chart(data.sorted(by: { $0.date < $1.date })) { point in
						LineMark(
							x: .value("时间", point.date),
							y: .value("平均情绪", point.average)
						)
						.interpolationMethod(.catmullRom)
						.foregroundStyle(.blue)

						PointMark(
							x: .value("时间", point.date),
							y: .value("平均情绪", point.average)
						)
						.foregroundStyle(.blue)
					}
					.chartXScale(domain: xDomain(for: window))
					.chartXAxis {
						AxisMarks(values: xAxisValues(for: window)) { value in
							AxisValueLabel {
								if let date = value.as(Date.self) {
									if window == 1 {
										// 小时显示
										Text(date, format: .dateTime.hour().locale(.current))
									} else {
										// 按日显示
										Text(date, format: .dateTime.month().day())
									}
								}
							}
						}
					}
					.chartYAxis {
						AxisMarks(position: .leading)
					}
					.frame(height: 200)
					.frame(maxWidth: .infinity)
				}
			}
		}
	}

	// MARK: - 动态步进
	private func strideStep(for window: Int) -> Int {
		switch window {
		case 90: return 15
		case 30: return 7
		case 7: return 1
		default: return 3 // 日视图中每3小时显示一个刻度
		}
	}

	// MARK: - X轴范围
	private func xDomain(for window: Int) -> ClosedRange<Date> {
		let cal = TimeZoneManager.shared.calendar
		let now = Date()
		if window == 1 {
			// 今日00:00到23:59
			let start = cal.startOfDay(for: now)
			let end = cal.date(byAdding: .hour, value: 23, to: start)!
			return start...end
		} else {
			let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(window - 1), to: now)!)
			return start...now
		}
	}

	// MARK: - X轴刻度
	private func xAxisValues(for window: Int) -> [Date] {
		let cal = TimeZoneManager.shared.calendar
		let now = Date()
		if window == 1 {
			let start = cal.startOfDay(for: now)
			return stride(from: 0, through: 24, by: strideStep(for: window))
				.compactMap { cal.date(byAdding: .hour, value: $0, to: start) }
		} else {
			return Array(stride(from: xDomain(for: window).lowerBound, through: now, by: Double(86400 * strideStep(for: window))))
		}
	}

	// MARK: - 动态平均值计算
	private func moodAverages(windowDays: Int) -> [MoodTrendPoint] {
		guard !appModel.moodEntries.isEmpty else { return [] }

		let calendar = TimeZoneManager.shared.calendar
		let now = calendar.startOfDay(for: Date())

		if windowDays == 1 {
			// 「日」模式：按小时聚合
			let todayEntries = appModel.moodEntries.filter { calendar.isDate($0.date, inSameDayAs: now) }
			guard !todayEntries.isEmpty else { return [] }

			var hourly: [Date: (sum: Int, count: Int)] = [:]
			for entry in todayEntries {
				let hour = calendar.date(bySetting: .minute, value: 0, of: entry.date)!
				let normalized = calendar.date(bySetting: .second, value: 0, of: hour)!
				var item = hourly[normalized] ?? (0, 0)
				item.sum += entry.value
				item.count += 1
				hourly[normalized] = item
			}

			return hourly.map { (key, value) in
				MoodTrendPoint(date: key, average: Double(value.sum) / Double(max(1, value.count)))
			}
			.sorted(by: { $0.date < $1.date })
		}

		// 其他窗口（周、月、季）
		let start = calendar.date(byAdding: .day, value: -(max(1, windowDays) - 1), to: now) ?? now
		let entries = appModel.moodEntries.filter { $0.date >= start }
		guard !entries.isEmpty else { return [] }

		var daily: [Date: (sum: Int, count: Int)] = [:]
		for entry in entries {
			let day = calendar.startOfDay(for: entry.date)
			var item = daily[day] ?? (0, 0)
			item.sum += entry.value
			item.count += 1
			daily[day] = item
		}

		// 聚合逻辑
		if windowDays >= 30 {
			var weekly: [Date: (sum: Int, count: Int)] = [:]
			for (day, value) in daily {
				if let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start {
					weekly[weekStart, default: (0, 0)].sum += value.sum / max(1, value.count)
					weekly[weekStart]!.count += 1
				}
			}

			return weekly.map { (key, value) in
				MoodTrendPoint(date: key, average: Double(value.sum) / Double(max(1, value.count)))
			}
			.sorted(by: { $0.date < $1.date })
		}

		return daily.map { (key, value) in
			MoodTrendPoint(date: key, average: Double(value.sum) / Double(max(1, value.count)))
		}
		.sorted(by: { $0.date < $1.date })
	}
}

private struct MoodTrendPoint: Identifiable {
	let date: Date
	let average: Double
	var id: Date { date }
}
