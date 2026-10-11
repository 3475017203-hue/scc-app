import Foundation
import UserNotifications

/// 到期提醒。抽象成协议是为了让"设提醒"这件事可测试——
/// 日期算对了但提醒没设上去，是这类 App 最常见的翻车点。
protocol ReminderScheduling: AnyObject {
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    func schedule(title: String, body: String, at date: Date, identifier: String)
    func cancel(identifier: String)
}

final class LocalReminderScheduler: ReminderScheduling {
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
    }

    func schedule(title: String, body: String, at date: Date, identifier: String) {
        guard date > Date() else { return }   // 已经能吃了就不必再提醒
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancel(identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

final class MockReminderScheduler: ReminderScheduling {
    private(set) var scheduled: [(title: String, body: String, date: Date, id: String)] = []
    private(set) var cancelled: [String] = []

    func requestAuthorization(completion: @escaping (Bool) -> Void) { completion(true) }

    func schedule(title: String, body: String, at date: Date, identifier: String) {
        scheduled.append((title, body, date, identifier))
    }

    func cancel(identifier: String) { cancelled.append(identifier) }
}
