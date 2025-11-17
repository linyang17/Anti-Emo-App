import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    enum AuthorizationResult {
        case granted
        case denied
        case requiresSettings
    }

    private let center = UNUserNotificationCenter.current()

    func requestNotiAuth(completion: @escaping (AuthorizationResult) -> Void) {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .denied:
                DispatchQueue.main.async { completion(.requiresSettings) }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(.granted) }
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async { completion(granted ? .granted : .denied) }
                }
                self.center.delegate = self
            @unknown default:
                DispatchQueue.main.async { completion(.denied) }
            }
        }
    }

    func scheduleDailyReminders() {
        let times = [(8, 0), (20, 30)]
        let identifiers = times.map { "LumioPet.reminder.\($0.0).\($0.1)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        times.forEach { hour, minute in
            let content = UNMutableNotificationContent()
            content.title = "Lumio's letter"
            content.body = "Lumio finds some new activities for you! Check out what they are."
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "LumioPet.reminder.\(hour).\(minute)"
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func scheduleTaskReminders(for tasks: [UserTask]) {
        guard !tasks.isEmpty else { return }
        center.getPendingNotificationRequests { [weak self] requests in
            let taskIdentifiers = requests
                .filter { $0.identifier.hasPrefix("LumioPet.task.") }
                .map { $0.identifier }
            if !taskIdentifiers.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: taskIdentifiers)
            }
            self?.enqueueTaskNotifications(for: tasks)
        }
    }

    private func enqueueTaskNotifications(for tasks: [UserTask]) {
        for task in tasks {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: task.date)
            if hour >= 22 || hour < 6 { continue }

            let content = UNMutableNotificationContent()
            content.title = "Lumio finds some new activities for you"
            content.body = task.title
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: task.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "LumioPet.task.\(task.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
		}
	}

	func notifyTasksUnlocked(for slot: TimeSlot) {
		let content = UNMutableNotificationContent()
		content.title = "新任务已准备好"
		content.body = slotNotificationMessage(for: slot)
		content.sound = .default

		let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
		let identifier = "LumioPet.task-unlock.\(UUID().uuidString)"
		let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
		center.add(request)
	}

	private func slotNotificationMessage(for slot: TimeSlot) -> String {
		switch slot {
		case .morning:
			return "早间活动开启，来陪 Lumio 出门透气吧！"
		case .afternoon:
			return "下午的活力任务上新了，看看有什么新挑战。"
		case .evening:
			return "傍晚的温馨任务已就绪，和 Lumio 一起放松。"
		case .night:
			return "夜晚是休息时间，记得按时睡觉。"
		}
	}
}
