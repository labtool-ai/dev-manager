import Foundation

/// 中英双语字符串表。t(key, lang) 取词，缺失回退到 key 本身。
enum Localization {
    enum Lang { case zh, en }

    static func t(_ key: String, _ lang: Lang) -> String {
        guard let entry = table[key] else { return key }
        return lang == .zh ? entry.zh : entry.en
    }

    // key : (中文, English)
    private static let table: [String: (zh: String, en: String)] = [
        // 通用
        "running":        ("运行中", "running"),
        "projects":       ("个项目", "projects"),
        "select_project": ("选择一个项目", "Select a project"),
        "new_process":    ("新建进程", "new process"),
        "settings":       ("设置", "settings"),
        "back":           ("返回", "back"),
        "open_devmanager":("打开 DevManager", "Open DevManager"),
        "quit_devmanager":("退出 DevManager", "Quit DevManager"),

        // 状态
        "state_running":  ("运行中", "running"),
        "state_starting": ("启动中…", "starting…"),
        "state_stopped":  ("已停止", "stopped"),

        // 新建 / 编辑面板
        "add_new_process":("新建进程", "Add New Process"),
        "edit_process":   ("编辑进程", "Edit Process"),
        "commands":       ("命令", "commands"),
        "add_command":    ("添加命令", "add command"),
        "add_command_verb":("添加", "add"),
        "name_auto":      ("名称自动", "name auto"),
        "tag_hint":       ("分类，可留空", "tag, optional"),
        "browse":         ("浏览", "Browse"),
        "cancel":         ("取消", "cancel"),
        "save":           ("保存", "save"),
        "auto_restart":   ("崩溃时自动重启", "restart on crash"),
        "port":           ("端口", "port"),
        "tags":           ("标签", "tags"),

        // 日志
        "filter_logs":    ("过滤日志", "filter logs"),

        // 设置 - tabs
        "tab_display":    ("外观", "display"),
        "tab_general":    ("通用", "general"),
        "tab_ports":      ("端口", "ports"),
        "tab_updates":    ("更新", "updates"),
        "tab_about":      ("关于", "about"),
        "tab_stats":      ("统计", "stats"),

        // 设置 - 端口
        "ports_title":        ("本机监听端口", "Listening ports"),
        "ports_desc":         ("哪些端口在用 · 什么进程占的", "what's using which port"),
        "ports_refresh":      ("刷新", "refresh"),
        "ports_loading":      ("扫描中…", "scanning…"),
        "ports_empty":        ("没有检测到监听端口", "no listening ports"),
        "ports_managed":      ("本应用", "managed"),
        "ports_open":         ("在浏览器打开", "open in browser"),
        "ports_kill":         ("结束进程", "kill"),
        "ports_kill_confirm": ("结束这个进程?", "Kill this process?"),
        "ports_count_suffix": ("个监听端口", "listening"),

        // 设置 - 统计
        "stat_total_runs":    ("总启动次数", "total runs"),
        "stat_total_runtime": ("累计运行时长", "total runtime"),
        "stat_longest_run":   ("最长单次运行", "longest run"),
        "stat_current_streak":("当前连续天数", "current streak"),
        "stat_longest_streak":("最长连续天数", "longest streak"),
        "launch_activity":    ("启动活动", "launch activity"),
        "insights":           ("活动洞察", "activity insights"),
        "top_projects":       ("最常用项目", "most-used projects"),
        "insight_projects":   ("项目总数", "total projects"),
        "insight_tags":       ("标签数", "tags"),
        "insight_avg_runtime":("平均单次时长", "avg runtime"),
        "insight_sessions":   ("总运行次数", "total runs"),
        "runs_unit":          ("次运行", "runs"),
        "no_stats":           ("还没有运行记录 —— 启动一个项目就会开始统计", "No runs yet — start a project to begin tracking"),
        "unit_days":          ("天", "days"),
        "mode_daily":         ("每日", "daily"),
        "mode_weekly":        ("每周", "weekly"),
        "mode_cumulative":    ("累计", "cumulative"),
        "insight_active_hour":("最活跃时段", "most active hour"),
        "insight_crashes":    ("崩溃次数", "crashes"),
        "sample_data":        ("示例数据", "sample data"),
        "clear":              ("清空", "clear"),
        "unit_runs_short":    ("次", "runs"),

        // 设置 - 外观
        "appearance":     ("外观", "appearance"),
        "appearance_system":("跟随系统", "follow system"),
        "appearance_light": ("浅色", "light"),
        "appearance_dark":  ("深色", "dark"),

        // 设置 - 通用
        "language":       ("语言", "language"),
        "lang_system":    ("跟随系统", "follow system"),
        "lang_zh":        ("中文", "中文"),
        "lang_en":        ("English", "English"),
        "launch_at_login":("开机自启", "launch at login"),
        "notifications":  ("崩溃/就绪通知", "crash/ready notifications"),
        "lang_note":      ("切换后界面即时更新", "changes apply instantly"),

        // 设置 - 更新
        "current_version":("当前版本", "current version"),
        "changelog":      ("更新日志", "changelog"),
        "check_updates":  ("检查更新", "check for updates"),
        "checking":       ("检查中…", "checking…"),
        "up_to_date":     ("已是最新版本", "up to date"),
        "update_available":("发现新版本", "update available"),
        "check_failed":   ("检查失败", "check failed"),
        "update_not_configured":("更新源未配置", "update source not configured"),
        "download":       ("下载", "download"),

        // 设置 - 关于
        "about_desc":     ("一个 macOS 原生本地开发进程管理器。", "A native macOS local dev-process manager."),
    ]
}
