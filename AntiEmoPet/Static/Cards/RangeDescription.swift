import Foundation

/// 根据时间窗口返回描述性字符串，例如：
/// - 1天模式："19 Nov 2025, 00:00 - 23:59"
/// - 7天模式："13 - 19 Nov 2025"
/// - 30天模式："20 Oct - 19 Nov 2025"
///
/// - Parameters:
///   - window: 时间窗口（1 = 日，7 = 周，30 = 月）
///   - calendar: 可选，自定义日历，默认使用 TimeZoneManager.shared.calendar
/// - Returns: 格式化的时间范围描述

func rangeDescription(for window: Int, calendar cal: Calendar = TimeZoneManager.shared.calendar) -> String {
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
	case 91:
		end = cal.startOfDay(for: now)
		let quarterAgoSameDay = cal.date(byAdding: .month, value: -3, to: end) ?? end
		start = cal.date(byAdding: .day, value: 1, to: quarterAgoSameDay) ?? quarterAgoSameDay
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
