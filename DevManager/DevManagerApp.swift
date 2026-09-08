import SwiftUI

/// AppDelegate 持有全局对象 + 自建菜单栏(NSStatusItem + NSPanel)。
/// 菜单栏不再用 SwiftUI 的 MenuBarExtra(.window)——那个宿主窗口不透明,拿不到原生毛玻璃。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = ProcessManager()
    let settings = AppSettings()
    let updater = UpdaterModel()
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(manager: manager, settings: settings)
    }
}

@main
struct DevManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var manager: ProcessManager { appDelegate.manager }
    private var settings: AppSettings { appDelegate.settings }

    var body: some Scene {
        // 完整主窗口（设置也内嵌在这里，全屏 + 返回）
        Window("DevManager", id: "main") {
            MainWindow()
                .environment(manager)
                .environment(settings)
                .environmentObject(appDelegate.updater)
                .frame(minWidth: 900, minHeight: 560)
                .preferredColorScheme(settings.colorScheme)
        }
        .windowResizability(.contentMinSize)
        .commands {
            // 让菜单 “Settings…” 和 ⌘, 打开内嵌设置页，而不是独立窗口
            CommandGroup(replacing: .appSettings) {
                Button(settings.t("settings")) {
                    settings.showSettings = true
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            // ⌘K 快速启动
            CommandGroup(after: .toolbar) {
                Button(settings.resolvedLanguage == .zh ? "快速启动" : "Quick Launch") {
                    settings.showPalette = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
