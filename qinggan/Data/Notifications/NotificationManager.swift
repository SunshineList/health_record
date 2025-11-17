import Foundation
import UserNotifications

final class NotificationManager {
    func requestPermission() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
    func scheduleDailyReminders(goal: Int, current: Int) {
        schedule(hour: 11, minute: 30, title: "步数提醒", body: bodyText(current: current, goal: goal, checkpoint: 0.3))
        schedule(hour: 17, minute: 0, title: "步数提醒", body: bodyText(current: current, goal: goal, checkpoint: 0.7))
        schedule(hour: 21, minute: 0, title: "步数提醒", body: bodyText(current: current, goal: goal, checkpoint: 1.0))
    }
    private func bodyText(current: Int, goal: Int, checkpoint: Double) -> String {
        let target = Int(Double(goal) * checkpoint)
        if current >= target { return "做得很好，继续保持日常活动！" }
        let remain = max(0, target - current)
        return "今天还差约 \(remain) 步可达到阶段目标，试着散步或拉伸。"
    }
    private func schedule(hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        var date = DateComponents(); date.hour = hour; date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "steps_\(hour)_\(minute)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}