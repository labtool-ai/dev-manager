import SwiftUI
import ServiceManagement

enum Appearance: String, CaseIterable { case system, light, dark }
enum Language: String, CaseIterable { case system, zh, en }

/// 全局设置：外观 / 语言，持久化到 UserDefaults，提供本地化取词 t()。
@Observable
@MainActor
final class AppSettings {
    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    var language: Language {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
            Notifier.lang = resolvedLanguage
        }
    }
    var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notifications)
            Notifier.enabled = notificationsEnabled
        }
    }
    /// 内存告警阈值(MB)，0 = 关闭
    var memAlertMB: Double {
        didSet { UserDefaults.standard.set(memAlertMB, forKey: Keys.memAlertMB) }
    }
    /// CPU 告警阈值(%)，0 = 关闭
    var cpuAlertPct: Double {
        didSet { UserDefaults.standard.set(cpuAlertPct, forKey: Keys.cpuAlertPct) }
    }

    /// 侧栏被折叠的分组名（持久化，进出设置页 / 重启后保持）
    var collapsedTags: Set<String> {
        didSet { UserDefaults.standard.set(Array(collapsedTags), forKey: Keys.collapsedTags) }
    }

    /// 瞬态：是否在主窗口内展示设置页（不持久化）
    var showSettings = false
    /// 瞬态：是否展示 ⌘K 快速启动面板
    var showPalette = false

    init() {
        let d = UserDefaults.standard
        appearance = Appearance(rawValue: d.string(forKey: Keys.appearance) ?? "") ?? .system
        language = Language(rawValue: d.string(forKey: Keys.language) ?? "") ?? .system
        notificationsEnabled = (d.object(forKey: Keys.notifications) as? Bool) ?? true
        memAlertMB = d.object(forKey: Keys.memAlertMB) as? Double ?? 0
        cpuAlertPct = d.object(forKey: Keys.cpuAlertPct) as? Double ?? 0
        collapsedTags = Set(d.stringArray(forKey: Keys.collapsedTags) ?? [])
        Notifier.enabled = notificationsEnabled
        Notifier.lang = resolvedLanguage
    }

    /// 应用到 SwiftUI 根视图
    var colorScheme: ColorScheme? {
        switch appearance {
        case .light: .light
        case .dark:  .dark
        case .system: nil
        }
    }

    var resolvedLanguage: Localization.Lang {
        switch language {
        case .zh: return Localization.Lang.zh
        case .en: return Localization.Lang.en
        case .system:
            let pref = Locale.preferredLanguages.first ?? "en"
            return pref.hasPrefix("zh") ? .zh : .en
        }
    }

    func t(_ key: String) -> String { Localization.t(key, resolvedLanguage) }

    // MARK: - 开机自启

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("launchAtLogin toggle failed: \(error)")
            }
        }
    }

    private enum Keys {
        static let appearance = "settings.appearance"
        static let language = "settings.language"
        static let notifications = "settings.notifications"
        static let memAlertMB = "settings.memAlertMB"
        static let cpuAlertPct = "settings.cpuAlertPct"
        static let collapsedTags = "sidebar.collapsedTags"
    }
}
