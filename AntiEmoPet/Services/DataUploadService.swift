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

struct SummarySlot: Codable {
	let time_slot: String
	let timeslot_weather: String?
	let day_length_min: Int?
	let avg_mood: Double?
	let task_feedback: [String: [Int]]?
	let energy_delta_sum: Int?
	let tasks_published: Int?
	let tasks_completed: Int?
}

struct SummaryDailyPayload: Codable {
	let user_id: String
	let profile: Profile?
	let target_date: String
	let mood_entries: Int
	let slots: [SummarySlot]

	struct Profile: Codable {
		let gender: String?
		let age_group: String?
		let country_region: String?
		let timezone: String
	}
}

//MARK: 上传到 SUPABASE

final class DataUploadService {
	static let shared = DataUploadService()
	private init() {}

	func uploadDailySummary(
		targetDate: String,
		moodEntries: Int,
		slots: [SummarySlot],
		profile: SummaryDailyPayload.Profile,
		completion: ((Bool) -> Void)? = nil
	) {
		let url = SUPABASEConfig.supabaseSummaryDailyURL   // 从 Info.plist 读取

		let payload = SummaryDailyPayload(
			user_id: UserIDManager.current,
			profile: profile,
			target_date: targetDate,
			mood_entries: moodEntries,
			slots: slots
		)

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
