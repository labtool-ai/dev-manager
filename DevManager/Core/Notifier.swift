import Foundation
import UserNotifications

/// 本地系统通知:进程崩溃 / 就绪时弹通知。可在设置里关闭。
enum Notifier {
    static var enabled = true
    static var lang: Localization.Lang = .en

    static func requestAuthIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notify(title: String, zh: String, en: String) {
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = lang == .zh ? zh : en
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
