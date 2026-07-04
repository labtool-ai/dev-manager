import SwiftUI

@main
struct DevManagerApp: App {
    @State private var manager = ProcessManager()
    @State private var settings = AppSettings()
    @StateObject private var updater = UpdaterModel()

    var body: some Scene {
        // 完整主窗口（设置也内嵌在这里，全屏 + 返回）
        Window("DevManager", id: "main") {
            MainWindow()
                .environment(manager)
                .environment(settings)
                .environmentObject(updater)
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

        // 菜单栏常驻入口
        MenuBarExtra {
            MenuBarView()
                .environment(manager)
                .environment(settings)
                .preferredColorScheme(settings.colorScheme)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)
    }
}
