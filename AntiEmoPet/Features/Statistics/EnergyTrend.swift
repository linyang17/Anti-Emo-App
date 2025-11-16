import SwiftUI
import Charts

struct EnergyTrendSection: View {
	@State private var window: Int = 7
	let energyHistory: [EnergyHistoryEntry]
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "Energy Trend", icon: "chart.bar.fill") {
			VStack(alignment: .leading, spacing: 24) {
								Picker("window", selection: $window) {
										Text("Day").tag(1)
										Text("Week").tag(7)
										Text("Month").tag(30)
								}
								.pickerStyle(.segmented)

								Text(rangeDescription(for: window))
										.font(.caption)
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
						Chart(data.sorted(by: { $0.key < $1.key }), id: \.key) { day, added in
								BarMark(
									x: .value(window == 1 ? "hour" : "day", day),
									y: .value("Energy Added", added)
								)
								.foregroundStyle(.green)
								.cornerRadius(4)
						}
						.chartScrollableAxes(.horizontal)
						.chartXScale(domain: xVisibleDomain(for: window, data: data))
						.chartXAxis {
							AxisMarks(values: xAxisValues(for: window)) { value in
								AxisValueLabel {
									if let date = value.as(Date.self) {
										switch window {
										case 1:
											Text(date, format: .dateTime.hour())
										case 7:
											// Week: show weekday abbreviation, e.g. Mon, Tue
											Text(date, format: .dateTime.weekday(.abbreviated))
												.font(.caption2)
										case 30:
											// Month: show day of month (dd) every tick
											Text(date, format: .dateTime.day())
												.font(.caption2)
										default:
											Text(date, format: .dateTime.day())
												.font(.caption2)
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

	// MARK: - 动态步进逻辑
		private func strideStep(for window: Int) -> Int {
			switch window {
			case 30:
				// Month：每 7 天一个刻度
				return 7
			case 7:
				// Week：每天一个刻度
				return 1
			default:
				// 日模式：每 3 小时一个刻度
				return 3
			}
		}

	// MARK: - 动态 X 轴范围
	// MARK: - 动态 X 轴刻度
		private func xAxisValues(for window: Int) -> [Date] {
			let cal = TimeZoneManager.shared.calendar
			let now = Date()

			if window == 1 {
				let start = cal.startOfDay(for: now)
				return stride(from: 0, through: 24, by: strideStep(for: window))
					.compactMap { cal.date(byAdding: .hour, value: $0, to: start) }
			} else {
				let end = cal.startOfDay(for: now)
				let stepDays = strideStep(for: window)

				let start: Date
				switch window {
				case 7:
					// 周：包含今天在内的前 7 天（共 7 天）
					start = cal.date(byAdding: .day, value: -6, to: end) ?? end
				case 30:
					// 月：前一个月到今天，例如 10.16 - 11.15
					let monthAgoSameDay = cal.date(byAdding: .month, value: -1, to: end) ?? end
					start = cal.date(byAdding: .day, value: 1, to: monthAgoSameDay) ?? monthAgoSameDay
				default:
					start = cal.date(byAdding: .day, value: -6, to: end) ?? end
				}

				var values: [Date] = []
				var cursor = start
				while cursor <= end {
					values.append(cursor)
					guard let next = cal.date(byAdding: .day, value: stepDays, to: cursor) else { break }
					cursor = next
				}
				if values.last != end {
					values.append(end)
				}
				return values
			}
		}

	private func xVisibleDomain(for window: Int, data: [Date: Int]) -> ClosedRange<Date> {
		let cal = TimeZoneManager.shared.calendar
		let now = Date()

		if window == 1 {
			// 日模式：X 轴固定为当天 0 点到第二天 0 点
			let start = cal.startOfDay(for: now)
			let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
			return start...end
		} else {
			let end = cal.startOfDay(for: now)
			let start: Date

			switch window {
			case 7:
				// 周：包含今天在内的前 7 天
				start = cal.date(byAdding: .day, value: -6, to: end) ?? end
			case 30:
				// 月：前一个月到今天，例如 10.16 - 11.15
				let monthAgoSameDay = cal.date(byAdding: .month, value: -1, to: end) ?? end
				start = cal.date(byAdding: .day, value: 1, to: monthAgoSameDay) ?? monthAgoSameDay
			default:
				start = cal.date(byAdding: .day, value: -6, to: end) ?? end
			}

			return start...end
		}
	}

		private func rangeDescription(for window: Int) -> String {
		let cal = TimeZoneManager.shared.calendar
		let now = Date()

		let start: Date
		let end: Date

		switch window {
		case 1:
			end = cal.startOfDay(for: now)
			start = end
		case 7:
			end = cal.startOfDay(for: now)
			start = cal.date(byAdding: .day, value: -6, to: end) ?? end
		case 30:
			end = cal.startOfDay(for: now)
			let monthAgoSameDay = cal.date(byAdding: .month, value: -1, to: end) ?? end
			start = cal.date(byAdding: .day, value: 1, to: monthAgoSameDay) ?? monthAgoSameDay
		default:
			end = cal.startOfDay(for: now)
			start = cal.date(byAdding: .day, value: -6, to: end) ?? end
		}

		let sameDay = cal.isDate(start, inSameDayAs: end)

		let dfDay = DateFormatter()
		dfDay.calendar = cal
		dfDay.locale = Locale.current
		dfDay.dateFormat = "d"

		let dfDayMonth = DateFormatter()
		dfDayMonth.calendar = cal
		dfDayMonth.locale = dfDay.locale
		dfDayMonth.dateFormat = "d MMM"

		let dfFull = DateFormatter()
		dfFull.calendar = cal
		dfFull.locale = dfDay.locale
		dfFull.dateFormat = "d MMM yyyy"

		if sameDay {
			let text = dfFull.string(from: end)
			return "\(text), 00:00 - 23:59"
		}

		let startYear = cal.component(.year, from: start)
		let endYear = cal.component(.year, from: end)
		let startMonth = cal.component(.month, from: start)
		let endMonth = cal.component(.month, from: end)

		if startYear == endYear && startMonth == endMonth {
			// 同月同年：9 - 15 Nov 2025
			let s = dfDay.string(from: start)
			let e = dfFull.string(from: end)
			return "\(s) - \(e)"
		} else if startYear == endYear {
			// 同年不同月：16 Oct - 15 Nov 2025
			let s = dfDayMonth.string(from: start)
			let e = dfFull.string(from: end)
			return "\(s) - \(e)"
		} else {
			// 跨年：28 Dec 2025 - 3 Jan 2026
			let s = dfFull.string(from: start)
			let e = dfFull.string(from: end)
			return "\(s) - \(e)"
		}
	}

	// MARK: - 动态数据计算
	private func dailyAdded(windowDays: Int) -> [Date: Int] {
		guard !energyHistory.isEmpty else { return [:] }

		let cal = TimeZoneManager.shared.calendar
		let now = Date()

		// 日模式：按小时计算
		if windowDays == 1 {
			let todayEntries = energyHistory.filter { cal.isDate($0.date, inSameDayAs: now) }
			guard !todayEntries.isEmpty else { return [:] }

			var hourly: [Date: Int] = [:]
			var prev: EnergyHistoryEntry?

			for entry in todayEntries.sorted(by: { $0.date < $1.date }) {
				let hour = cal.date(bySetting: .minute, value: 0, of: entry.date)!
				if let p = prev {
					let diff = entry.totalEnergy - p.totalEnergy
					if diff > 0 {
						hourly[hour, default: 0] += diff
					}
				}
				prev = entry
			}

			return hourly
		}

		// 周 / 月 / 季 模式：先对全部历史做聚合，再通过 chart 的 visible domain 控制滚动窗口
		let filtered = energyHistory
			.sorted(by: { $0.date < $1.date })

		var daily: [Date: Int] = [:]
		var prev: EnergyHistoryEntry?

		for entry in filtered {
			let day = cal.startOfDay(for: entry.date)
			if let p = prev {
				let diff = entry.totalEnergy - p.totalEnergy
				if diff > 0 { daily[day, default: 0] += diff }
			}
			prev = entry
		}

		daily[cal.startOfDay(for: now)] = energy.todayAdd
		
		// Week 和 Month 都按天显示
		return daily
	}
}
