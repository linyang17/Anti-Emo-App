import SwiftUI
import Charts

struct MoodTrendSection: View {
	@EnvironmentObject private var appModel: AppViewModel
	@State private var window: Int = 7

	var body: some View {
		DashboardCard(title: "Mood Trend", icon: "chart.line.uptrend.xyaxis") {
				VStack(alignment: .leading, spacing: 24) {
					Picker("window", selection: $window) {
						Text("Day").tag(1)
						Text("Week").tag(7)
						Text("Month").tag(30)
						Text("3M").tag(91)
					}
					.pickerStyle(.segmented)
					
					Text(rangeDescription(for: window))
						.appFont(FontTheme.caption)
						.foregroundStyle(.secondary)
					
					let data = moodAverages(windowDays: window)
					
					if data.isEmpty {
						ContentUnavailableView(
							"No Data",
							systemImage: "chart.line.uptrend.xyaxis",
							description: Text("Unlock when you record more moods")
						)
						.frame(height: 200)
						.frame(maxWidth: .infinity)
					} else {
						let yMin = max(0, (data.map(\.average).min() ?? 0) - 10)
						let yMax = min(100, (data.map(\.average).max() ?? 100) + 10)
						
						Chart(data.sorted(by: { $0.date < $1.date })) { point in
							LineMark(
								x: .value("time", point.date, unit: window == 1 ? .hour : window == 91 ? .weekOfYear : .day),
								y: .value("Avg Mood", point.average)
							)
							.interpolationMethod(.catmullRom)
							.foregroundStyle(
								LinearGradient(
									colors: ChartTheme.shared.grad_purple,
									startPoint: .bottom,
									endPoint: .top
								)
							)
							
							PointMark(
								x: .value("time", point.date, unit: window == 1 ? .hour : window == 91 ? .weekOfYear : .day),
								y: .value("Avg Mood", point.average)
							)
							.foregroundStyle(.purple)
						}
						.chartXScale(domain: xDomain(for: window))
						.chartYScale(domain: yMin...yMax)
						.chartXAxis {
							AxisMarks(values: xAxisValues(for: window)) { value in
								AxisGridLine()
								AxisTick()
								AxisValueLabel() {
									if let date = value.as(Date.self) {
										if window == 1 {
											Text(date, format: .dateTime.hour())
										} else if window == 7 {
											Text(date, format: .dateTime.weekday(.abbreviated))
										} else {
											Text(date, format: .dateTime.month(.abbreviated).day())
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
						.chartPlotStyle { plotArea in plotArea.padding(.trailing, 12) }
					}
				}
			}
		}
	// MARK: - 动态步进
	private func strideStep(for window: Int) -> Int {
		switch window {
		case 91: return 15
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
			let end = cal.date(byAdding: .hour, value: 26, to: start)!
			return start...end
		}
		else if window >= 45 {
			// 对于3M窗口，改为以“周”为单位的domain
			let weekCal = WeekAlignmentService.weeklyCalendar(from: cal)
			let start = WeekAlignmentService.weekAlignedStart(for: window, now: now, calendar: weekCal)
			let end = WeekAlignmentService.weekAlignedEnd(for: now, calendar: weekCal)
			return start...end
		}
		else {
			let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(window - 1), to: now)!)
			let paddedEnd = cal.startOfDay(for: cal.date(byAdding: .day, value: (window + 3) / 7, to: now)!
			)
			return start...paddedEnd
		}
	}

	// MARK: - X轴刻度
	private func xAxisValues(for window: Int) -> [Date] {
                let domain = xDomain(for: window)
                if window == 1 {
                        return Array(
                                stride(
                                        from: domain.lowerBound,
                                        through: domain.upperBound,
                                        by: Double(3600 * strideStep(for: window))
                                )
                        )
		}
		else if window >= 45 {
			// 对于3M模式，使用按周为步长的刻度
			return Array(
				stride(
					from: domain.lowerBound,
					through: domain.upperBound,
					by: Double(86400 * strideStep(for: window))
				)
			)
		}
		else {
			return Array(
				stride(
					from: domain.lowerBound,
					through: domain.upperBound,
					by: Double(86400 * strideStep(for: window))
				)
			)
		}
	}

	// MARK: - 动态平均值计算
	private func moodAverages(windowDays: Int) -> [MoodTrendPoint] {
		guard !appModel.moodEntries.isEmpty else { return [] }

		let calendar = TimeZoneManager.shared.calendar
		let now = Date()

		if windowDays == 1 {
			// 「日」模式：按小时聚合
				let todayEntries = appModel.moodEntries.filter { calendar.isDate($0.date, inSameDayAs: now) }
				guard !todayEntries.isEmpty else { return [] }

                                let groupedByHour = Dictionary(grouping: todayEntries) { entry in
                                                calendar.dateInterval(of: .hour, for: entry.date)!.start
                                }

				var averaged: [MoodTrendPoint] = []
				for (hour, group) in groupedByHour {
						let total = group.reduce(0.0) { $0 + Double($1.value) }
						let avg = total / Double(max(1, group.count))
						averaged.append(MoodTrendPoint(date: hour, average: avg))
				}

				return averaged.sorted { $0.date < $1.date }
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

		if windowDays >= 45 {
			let weekCal = WeekAlignmentService.weeklyCalendar(from: calendar)
			var weekly: [Date: (sum: Int, count: Int)] = [:]
			for (day, value) in daily {
					let weekStart = WeekAlignmentService.startOfWeek(for: day, calendar: weekCal)
					weekly[weekStart, default: (0, 0)].sum += value.sum / max(1, value.count)
					weekly[weekStart]!.count += 1
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
