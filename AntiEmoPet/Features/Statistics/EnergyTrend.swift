import SwiftUI
import Charts

struct EnergyTrendSection: View {
	@State private var window: Int = 7
	let energyHistory: [EnergyHistoryEntry]
	let energy: EnergyStatisticsViewModel.EnergySummary

	var body: some View {
		DashboardCard(title: "能量趋势", icon: "chart.bar.fill") {
			VStack(alignment: .leading, spacing: 15) {
                                Picker("窗口", selection: $window) {
                                        Text("日").tag(1)
                                        Text("周").tag(7)
                                        Text("月").tag(30)
                                        Text("季").tag(90)
                                }
                                .pickerStyle(.segmented)

                                Text(rangeDescription(for: window))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

				let data = dailyAdded(windowDays: window)

				if data.isEmpty {
					ContentUnavailableView(
						"暂无数据",
						systemImage: "chart.bar.fill",
						description: Text("完成更多任务后可以解锁")
					)
					.frame(height: 200)
					.frame(maxWidth: .infinity)
				} else {
                                        Chart(data.sorted(by: { $0.key < $1.key }), id: \.key) { day, added in
                                                BarMark(
                                                        x: .value(window == 1 ? "时间" : "日期", day),
                                                        y: .value("补充能量", added)
                                                )
                                                .foregroundStyle(.green)
                                                .cornerRadius(4)
                                        }
                                        .chartXScale(domain: xDomain(for: window))
                                        .chartXAxis {
                                                AxisMarks(values: xAxisValues(for: window)) { value in
                                                        AxisValueLabel {
                                                                if let date = value.as(Date.self) {
                                                                        if window == 1 {
                                                                                Text(date, format: .dateTime.hour())
                                                                        } else {
                                                                                Text(date, format: .dateTime.month().day())
                                                                                        .font(.caption2)
                                                                                        .rotationEffect(window > 1 ? .degrees(-35) : .zero)
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
                case 90: return 15
                case 30: return 5
                case 7: return 2
                default: return 3 // 日模式：每3小时一个刻度
                }
        }

	// MARK: - 动态 X 轴范围
	private func xDomain(for window: Int) -> ClosedRange<Date> {
		let cal = TimeZoneManager.shared.calendar
		let now = Date()

		if window == 1 {
			let start = cal.startOfDay(for: now)
			let end = cal.date(byAdding: .hour, value: 23, to: start)!
			return start...end
		} else {
			let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(window - 1), to: now)!)
			return start...now
		}
	}

	// MARK: - 动态 X 轴刻度
        private func xAxisValues(for window: Int) -> [Date] {
                let cal = TimeZoneManager.shared.calendar
                let now = Date()

                if window == 1 {
			let start = cal.startOfDay(for: now)
			return stride(from: 0, through: 24, by: strideStep(for: window))
				.compactMap { cal.date(byAdding: .hour, value: $0, to: start) }
		} else {
                        let stepDays = strideStep(for: window)
                        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(window - 1), to: now)!)
                        var values: [Date] = []
                        var cursor = start
                        while cursor <= now {
                                values.append(cursor)
                                guard let next = cal.date(byAdding: .day, value: stepDays, to: cursor) else { break }
                                cursor = next
                        }
                        if values.last != cal.startOfDay(for: now) {
                                values.append(cal.startOfDay(for: now))
                        }
                        return values
                }
        }

        private func rangeDescription(for window: Int) -> String {
                let cal = TimeZoneManager.shared.calendar
                let now = Date()
                let formatter = DateFormatter()
                formatter.calendar = cal
                formatter.locale = Locale(identifier: "zh_CN")
                formatter.dateFormat = "MM.dd"

                switch window {
                case 1:
                        let start = cal.startOfDay(for: now)
                        let end = cal.date(byAdding: .hour, value: 23, to: start) ?? now
                        let timeFormatter = DateFormatter()
                        timeFormatter.calendar = cal
                        timeFormatter.locale = formatter.locale
                        timeFormatter.dateFormat = "HH:mm"
                        return "范围：\(formatter.string(from: start)) \(timeFormatter.string(from: start)) – \(timeFormatter.string(from: end))"
                default:
                        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(window - 1), to: now)!)
                        return "范围：\(formatter.string(from: start)) – \(formatter.string(from: now))"
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

			// 当前小时使用实时 todayAdd
			let currentHour = cal.date(bySetting: .minute, value: 0, of: now)!
			hourly[currentHour, default: 0] += energy.todayAdd
			return hourly
		}

		// 周 / 月 / 季 模式
		let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -(windowDays - 1), to: now)!)
		let filtered = energyHistory.filter { $0.date >= start }
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

		if windowDays >= 30 {
			var weekly: [Date: (sum: Int, count: Int)] = [:]
			for (day, value) in daily {
				if let weekStart = cal.dateInterval(of: .weekOfYear, for: day)?.start {
					weekly[weekStart, default: (0, 0)].sum += value
					weekly[weekStart]!.count += 1
				}
			}
			return weekly.mapValues { $0.count > 0 ? $0.sum / $0.count : 0 }
		}

		return daily
	}
}
