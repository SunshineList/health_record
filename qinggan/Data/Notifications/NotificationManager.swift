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
    func scheduleMealReminders() {
        schedule(hour: 8, minute: 0, title: "早餐记录🍳", body: "拍照或手动记录早餐，养成好习惯！")
        schedule(hour: 12, minute: 30, title: "午餐记录🍱", body: "午餐适量，蛋白质优先～")
        schedule(hour: 18, minute: 30, title: "晚餐记录🍲", body: "晚餐清淡些，注意控制油脂")
        schedule(hour: 21, minute: 30, title: "加餐记录🍎", body: "如有加餐，优先选择低热量水果或酸奶")
    }
    func scheduleHydrationReminders() {
        schedule(hour: 10, minute: 0, title: "喝水提醒💧", body: "补一杯水，维持日常补水")
        schedule(hour: 15, minute: 0, title: "喝水提醒💧", body: "下午茶时间也要补水哦")
    }
    func scheduleWeightReminder() {
        schedule(hour: 21, minute: 0, title: "体重记录📈", body: "睡前称重并记录一次，观察趋势")
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