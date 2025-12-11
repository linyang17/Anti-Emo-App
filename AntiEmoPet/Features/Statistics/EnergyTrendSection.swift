import SwiftUI
import Charts

struct EnergyTrendSection: View {
        let energyHistory: [EnergyHistoryEntry]
        let energyEvents: [EnergyEvent]
        let energy: EnergyStatisticsViewModel.EnergySummary
	@State private var window: Int = 7

	var body: some View {
		DashboardCard(title: "Energy Trend", icon: "chart.bar.fill") {
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

                                let data = dailyAdded(windowDays: window)

				if data.isEmpty {
					ContentUnavailableView(
						"No Data",
						systemImage: "chart.bar.fill",
						description: Text("Unlock when you complete tasks")
					)
					.frame(height: 200)
					.frame(maxWidth: .infinity)
				} else {
					Chart(data.sorted(by: { $0.date < $1.date })) { point in
							BarMark(
								x: .value(
										"time",
										point.date,
										unit: window == 1 ? .hour : window == 91 ? .weekOfYear : .day
									),
								y: .value("Energy Added", point.averageTotal),
								width: .ratio(0.5)
							)
							.foregroundStyle(LinearGradient(colors: ChartTheme.shared.grad_orange, startPoint: .top, endPoint: .bottom))

					}
					.chartXScale(domain: xDomain(for: window))
					.chartXAxis {
						AxisMarks(values: xAxisValues(for: window)) { value in
							AxisGridLine()
							AxisTick()
							AxisValueLabel(collisionResolution: .greedy) {
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
		case 91: return 15 // 季视图中每2周显示一个刻度
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
				// 对于月或3M窗口，改为以“周”为单位的domain
			let start = cal.date(byAdding: .weekOfYear, value: -13, to: now)! // 3M约12周
			let end = cal.date(byAdding: .weekOfYear, value: 2, to: now)!
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
        private func dailyAdded(windowDays: Int) -> [EnergyTrendPoint] {
                let cal = TimeZoneManager.shared.calendar
                let now = Date()

                        // 日模式：按小时计算
                if windowDays == 1 {
                        let todayEvents = energyEvents.filter { cal.isDate($0.date, inSameDayAs: now) && $0.delta > 0 }
                        if !todayEvents.isEmpty {
                                var hourly: [Date: Int] = [:]
                                for event in todayEvents {
                                        let hour = cal.dateInterval(of: .hour, for: event.date)!.start
                                        hourly[hour, default: 0] += event.delta
                                }
                                return hourly.map { (key, value) in
                                        EnergyTrendPoint(date: key, averageTotal: Double(value))
                                }
                        }

                        guard !energyHistory.isEmpty else { return [] }

                        let todayEntries = energyHistory.filter { cal.isDate($0.date, inSameDayAs: now) }
                        guard !todayEntries.isEmpty else { return [] }

                        var hourly: [Date: Int] = [:]
                        let startOfDay = cal.startOfDay(for: now)
                        let previousSnapshot = energyHistory
                                .filter { $0.date < startOfDay }
                                .sorted(by: { $0.date < $1.date })
                                .last
                        var prev: EnergyHistoryEntry? = previousSnapshot

                        for entry in todayEntries.sorted(by: { $0.date < $1.date }) {
                                let hour = cal.dateInterval(of: .hour, for: entry.date)!.start
                                guard let p = prev else {
                                        // Use the first entry as baseline to avoid counting imports as gains
                                        prev = entry
                                        continue
                                }

                                let diff = entry.totalEnergy - p.totalEnergy
                                if diff > 0 {
                                        hourly[hour, default: 0] += diff
                                } else {
                                                // Still include the hour even if no gain
                                        hourly[hour, default: 0] = hourly[hour] ?? 0
                                }

                                prev = entry
                        }

                        return hourly.map { (key, value) in
                                EnergyTrendPoint(date: key, averageTotal: Double(value))
                        }
                }

                guard !energyHistory.isEmpty else { return [] }

		// 其他窗口（周、月、季）
		let start = cal.date(byAdding: .day, value: -(max(1, windowDays) - 1), to: now) ?? now
		let entries = energy.dailyEnergyAdds.filter { $0.key >= start }
		guard !entries.isEmpty else { return [] }

		var daily: [Date: (sum: Int, count: Int)] = [:]
		for entry in entries {
			let day = cal.startOfDay(for: entry.key)
			var item = daily[day] ?? (0, 0)
			item.sum += entry.value
			item.count += 1
			daily[day] = item
		}
		
		// 聚合逻辑
		if windowDays >= 45 {
			var weekly: [Date: (sum: Int, count: Int)] = [:]
			for (day, value) in daily {
				if let weekStart = cal.dateInterval(of: .weekOfYear, for: day)?.start {
					let midpoint = cal.date(byAdding: .day, value: 3, to: weekStart)!
					weekly[midpoint, default: (0, 0)].sum += value.sum / max(1, value.count)
					weekly[midpoint]!.count += 1
				}
			}

			return weekly.map { (key, value) in
				EnergyTrendPoint(date: key, averageTotal: Double(value.sum) / Double(max(1, value.count)))
			}
			.sorted(by: { $0.date < $1.date })
		}

		return entries.map { (key, value) in
			EnergyTrendPoint(date: key, averageTotal: Double(value))
		}
		.sorted(by: { $0.date < $1.date })
	}
}

private struct EnergyTrendPoint: Identifiable {
	let date: Date
	let averageTotal: Double
	var id: Date { date }
}
