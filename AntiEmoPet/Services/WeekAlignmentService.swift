import Foundation

enum WeekAlignmentService {
		static func weeklyCalendar(from calendar: Calendar) -> Calendar {
				var weekCal = calendar
				weekCal.firstWeekday = 2 // Monday
				weekCal.minimumDaysInFirstWeek = 1
				return weekCal
		}

		static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
				let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
				return calendar.date(from: components) ?? calendar.startOfDay(for: date)
		}

		static func weekAlignedStart(for window: Int, now: Date, calendar: Calendar) -> Date {
				let windowStart = calendar.date(byAdding: .day, value: -(max(1, window) - 1), to: now) ?? now
				return startOfWeek(for: windowStart, calendar: calendar)
		}

		static func weekAlignedEnd(for now: Date, calendar: Calendar) -> Date {
				let currentWeekStart = startOfWeek(for: now, calendar: calendar)
				return calendar.date(byAdding: .weekOfYear, value: 2, to: currentWeekStart) ?? now
		}
}


enum AppClock {

	/// Debug 模式可覆盖“现在”
	static var debugNow: Date?

	static var now: Date {
		#if DEBUG
		return debugNow ?? Date()
		#else
		return Date()
		#endif
	}

	static func todayStart(using calendar: Calendar) -> Date {
		calendar.startOfDay(for: now)
	}
}
