import Foundation

// MARK: 生成+持久化匿名 user_id

struct UserIDManager {
	private static let key = "AntiEmoUserID"

	static var current: String {
		if let existing = UserDefaults.standard.string(forKey: key) {
			return existing
		}
		let newID = UUID().uuidString
		UserDefaults.standard.set(newID, forKey: key)
		return newID
	}
}

// MARK: 构造请求并发送

/// Edge Function expects { "summaries": [ ... ] }
struct SummaryDailyRequest: Codable {
	let summaries: [UserTimeslotSummaryDTO]
}

/// DTO that matches the Edge Function schema (date as yyyy-MM-dd, dayLength in seconds)
struct UserTimeslotSummaryDTO: Codable {
	let userId: String
	let countryRegion: String

	let date: String            // yyyy-MM-dd (startOfDay)
	let dayLength: Int          // seconds
	let timeSlot: String

	let timeslotWeather: String?

	let countMood: Int
	let avgMood: Double
	let totalEnergyGain: Int
	let moodDeltaAfterTasks: Double

	let tasksSummary: [String: [Int]]

	init(from summary: UserTimeslotSummary) {
		self.userId = summary.userId
		self.countryRegion = summary.countryRegion
		self.date = DateFormatters.localDayString(from: summary.date)
		self.dayLength = max(0, Int(summary.dayLength.rounded()))
		self.timeSlot = summary.timeSlot
		self.timeslotWeather = summary.timeslotWeather
		self.countMood = max(0, summary.countMood)
		self.avgMood = summary.avgMood
		self.totalEnergyGain = summary.totalEnergyGain
		self.moodDeltaAfterTasks = summary.moodDeltaAfterTasks
		self.tasksSummary = summary.tasksSummary
	}
}

enum DateFormatters {
	/// Formats a Date into yyyy-MM-dd in the user's current time zone.
	static func localDayString(from date: Date) -> String {
		let formatter = DateFormatter()
		formatter.calendar = Calendar.current
		formatter.timeZone = TimeZone.current
		formatter.dateFormat = "yyyy-MM-dd"
		return formatter.string(from: date)
	}
}

final class DataUploadService {
	static let shared = DataUploadService()
	init() {}

	/// Users do not interact with this; it runs automatically in the background.
	func uploadTimeslotSummaries(
		_ summaries: [UserTimeslotSummary],
		completion: ((Bool) -> Void)? = nil
	) {
		guard !summaries.isEmpty else {
			completion?(true)
			return
		}

		let url = SUPABASEConfig.supabaseSummaryDailyURL

		// Ensure summaries carry the current anonymous user id (safety net)
		let currentUserId = UserIDManager.current
		let normalized: [UserTimeslotSummary] = summaries.map { s in
			if s.userId == currentUserId { return s }
			// If upstream accidentally passed a different userId, prefer the local persisted one.
			return UserTimeslotSummary(
				userId: currentUserId,
				countryRegion: s.countryRegion,
				date: s.date,
				dayLength: s.dayLength,
				timeSlot: s.timeSlot,
				timeslotWeather: s.timeslotWeather,
				countMood: s.countMood,
				avgMood: s.avgMood,
				totalEnergyGain: s.totalEnergyGain,
				moodDeltaAfterTasks: s.moodDeltaAfterTasks,
				tasksSummary: s.tasksSummary
			)
		}

		let dto = normalized.map { UserTimeslotSummaryDTO(from: $0) }
		let payload = SummaryDailyRequest(summaries: dto)

		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		do {
			request.httpBody = try JSONEncoder().encode(payload)
		} catch {
			print("Encode payload error:", error)
			completion?(false)
			return
		}

		URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				print("Upload summary error:", error)
				completion?(false)
				return
			}

			guard let data = data else {
				completion?(false)
				return
			}

			let ok =
				(try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["ok"]
				as? Bool ?? false

			completion?(ok)
		}.resume()
	}
}

//MARK: 读取 URL
enum SUPABASEConfig {

	static var supabaseSummaryDailyURL: URL {
		guard
			let urlString = Bundle.main.object(
				forInfoDictionaryKey: "SUPABASE_SUMMARY_DAILY_URL"
			) as? String,
			let url = URL(string: urlString)
		else {
			fatalError("❌ Missing or invalid SUPABASE_SUMMARY_DAILY_URL in Info.plist")
		}
		return url
	}
}
