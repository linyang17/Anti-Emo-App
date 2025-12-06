import Foundation
import UserNotifications

/// A centralized manager for all user notification requests related to LumioPet.
/// Handles authorization, scheduling daily and task reminders, and dynamic slot-based unlock alerts.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

	// MARK: - Types

	enum AuthorizationResult {
		case granted
		case denied
		case requiresSettings
	}

	// MARK: - Properties

	private let center = UNUserNotificationCenter.current()

	// MARK: - Initialization

	override init() {
		super.init()
		center.delegate = self
	}

	// MARK: - Authorization

	/// Requests authorization for notifications and returns the result via completion handler.
	func requestNotiAuth(completion: @escaping (AuthorizationResult) -> Void) {
		Task {
			let settings = await center.notificationSettings()
			switch settings.authorizationStatus {
			case .denied:
				completion(.requiresSettings)
			case .authorized, .provisional, .ephemeral:
				completion(.granted)
			case .notDetermined:
				do {
					let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
					completion(granted ? .granted : .denied)
				} catch {
					completion(.denied)
				}
			@unknown default:
				completion(.denied)
			}
		}
	}

	// MARK: - Daily Reminder Scheduling

	/// Schedules daily reminders at fixed times (default: 8:00 AM and 8:30 PM).
	func scheduleDailyReminders() {
		let times: [(hour: Int, minute: Int)] = [(8, 0), (20, 30)]
		let identifiers = times.map { "LumioPet.reminder.\($0.hour).\($0.minute)" }

		center.removePendingNotificationRequests(withIdentifiers: identifiers)

		for (hour, minute) in times {
			let content = UNMutableNotificationContent().apply {
				$0.title = "Lumio’s Letter"
				$0.body = "Lumio found new activities for you! Check them out now."
				$0.sound = .default
			}

			var components = DateComponents()
			components.hour = hour
			components.minute = minute

			let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
			let request = UNNotificationRequest(
				identifier: "LumioPet.reminder.\(hour).\(minute)",
				content: content,
				trigger: trigger
			)

			center.add(request)
		}
	}

	// MARK: - Task Reminder Scheduling

        /// Schedules notifications for a given list of user tasks. Clears existing task notifications, then enqueues the new ones.
        /// - Parameters:
        ///   - tasks: Tasks to schedule.
        ///   - allowedSlots: Slots that are permitted to surface notifications.
        func scheduleTaskReminders(for tasks: [UserTask], allowedSlots: Set<TimeSlot> = Set(TimeSlot.allCases)) async {
                guard !tasks.isEmpty else { return }

                let requests = await center.pendingNotificationRequests()
                let oldTaskIDs = requests
                        .filter { $0.identifier.hasPrefix("LumioPet.task.") }
			.map(\.identifier)

		if !oldTaskIDs.isEmpty {
			center.removePendingNotificationRequests(withIdentifiers: oldTaskIDs)
		}
		
                enqueueTaskNotifications(for: tasks, allowedSlots: allowedSlots)
        }

        /// Creates and enqueues individual task notifications.
        private func enqueueTaskNotifications(for tasks: [UserTask], allowedSlots: Set<TimeSlot>) {
                let calendar = Calendar.current

                for task in tasks {
                        let slot = TimeSlot.from(date: task.date, using: calendar)
                        guard allowedSlots.contains(slot) else { continue }
                        let hour = calendar.component(.hour, from: task.date)
                        guard (6..<22).contains(hour) else { continue }

			let content = UNMutableNotificationContent().apply {
				$0.title = "Lumio found some new activities for you"
				$0.body = task.title
				$0.sound = .default
			}

			let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: task.date)
			let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

			let request = UNNotificationRequest(
				identifier: "LumioPet.task.\(task.id.uuidString)",
				content: content,
				trigger: trigger
			)

			center.add(request)
		}
	}

	// MARK: - Slot Notifications

        /// Sends an instant notification when a time slot unlocks new tasks.
        func notifyTasksUnlocked(for slot: TimeSlot, allowedSlots: Set<TimeSlot> = Set(TimeSlot.allCases)) {
                guard allowedSlots.contains(slot) else { return }
                let content = UNMutableNotificationContent().apply {
                        $0.title = "New tasks are ready!"
                        $0.body = slotNotificationMessage(for: slot)
                        $0.sound = .default
                }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let identifier = "LumioPet.task-unlock.\(slot.rawValue).\(UUID().uuidString)"

                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request)
        }

        /// Pre-schedules unlock notifications for the provided slot schedule so they fire even when the app is closed.
        func scheduleSlotUnlocks(for schedule: [TimeSlot: Date], allowedSlots: Set<TimeSlot>) {
                let identifiers = schedule.keys.map { "LumioPet.task-unlock.\($0.rawValue)" }
                center.removePendingNotificationRequests(withIdentifiers: identifiers)

                for (slot, date) in schedule where allowedSlots.contains(slot) {
                        let content = UNMutableNotificationContent().apply {
                                $0.title = "New tasks are ready!"
                                $0.body = slotNotificationMessage(for: slot)
                                $0.sound = .default
                        }

                        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                        let request = UNNotificationRequest(
                                identifier: "LumioPet.task-unlock.\(slot.rawValue)",
                                content: content,
                                trigger: trigger
                        )
                        center.add(request)
                }
        }

	/// Returns the appropriate notification message for a given time slot.
	private func slotNotificationMessage(for slot: TimeSlot) -> String {
		switch slot {
		case .morning:
			"Morning, get the day started with Lumio!"
		case .afternoon:
			"Check out some fun activities for today!"
		case .evening:
			"It's been a long day, but you've got this. Keep going!"
		case .night:
			"Time to wind down and recharge."
		}
	}

	// MARK: - UNUserNotificationCenterDelegate

	func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification,
		withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
	) {
		completionHandler([.banner, .sound])
	}
}

// MARK: - Helper Extension

private extension UNMutableNotificationContent {
	/// Allows inline mutation in a functional style.
	func apply(_ updates: (UNMutableNotificationContent) -> Void) -> UNMutableNotificationContent {
		updates(self)
		return self
	}
}
