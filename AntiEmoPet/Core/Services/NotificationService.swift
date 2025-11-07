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
        center.removeAllPendingNotificationRequests()
        times.forEach { hour, minute in
            let content = UNMutableNotificationContent()
            content.title = "SunnyPet 提醒"
            content.body = "来看看你今天的阳光任务吧！"
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "sunnyPet.reminder.\(hour).\(minute)",
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
}
