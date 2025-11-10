import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        center.delegate = self
        // TODO(中/EN): Surface in-app banner when用户拒绝权限, guiding them to Settings per PRD 通知 fallback.
    }

    func scheduleDailyReminders() {
        let times = [(8, 0), (20, 30)]
        let identifiers = times.map { "sunnyPet.reminder.\($0.0).\($0.1)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        times.forEach { hour, minute in
            let content = UNMutableNotificationContent()
            content.title = "SunnyPet 提醒"
            content.body = "来看看sunny吧！"
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "sunnyPet.reminder.\(hour).\(minute)"
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

    func scheduleTaskReminders(for tasks: [Task]) {
        guard !tasks.isEmpty else { return }
        center.getPendingNotificationRequests { [weak self] requests in
            let taskIdentifiers = requests
                .filter { $0.identifier.hasPrefix("sunnyPet.task.") }
                .map { $0.identifier }
            if !taskIdentifiers.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: taskIdentifiers)
            }
            self?.enqueueTaskNotifications(for: tasks)
        }
    }

    private func enqueueTaskNotifications(for tasks: [Task]) {
        for task in tasks {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: task.date)
            if hour >= 22 || hour < 6 { continue }

            let content = UNMutableNotificationContent()
            content.title = "SunnyPet 新任务"
            content.body = task.title
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: task.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = "sunnyPet.task.\(task.id.uuidString)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }
}
