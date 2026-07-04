import SwiftUI

struct MainWindow: View {
    @Environment(ProcessManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @State private var selection: UUID?
    @State private var showingAdd = false
    @State private var hotKey: GlobalHotKey?
    @State private var showMergedLog = false

    var body: some View {
        Group {
            if settings.showSettings {
                SettingsView(onBack: { settings.showSettings = false })
            } else {
                projectsView
            }
        }
        .overlay {
            if settings.showPalette {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                        .onTapGesture { settings.showPalette = false }
                    CommandPalette(selection: $selection)
                        .padding(.bottom, 80)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: settings.showPalette)
        .onChange(of: selection) { _, v in
            if v != nil { showMergedLog = false }   // 选中项目就退出合并日志视图
        }
        .onAppear {
            Notifier.requestAuthIfNeeded()
            manager.startControlServer()
            guard hotKey == nil else { return }
            let hk = GlobalHotKey()               // 默认 ⌘⌥K 全局唤起
            hk.onFire = {
                NSApp.activate(ignoringOtherApps: true)
                settings.showPalette = true
            }
            hotKey = hk
        }
    }

    private var projectsView: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(280)
        } detail: {
            Group {
                if showMergedLog {
                    MergedLogView()
                } else if let id = selection, let proc = manager.process(for: id) {
                    DetailView(proc: proc, selection: $selection)
                } else {
                    ContentPlaceholder()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showMergedLog.toggle() } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                    .help(settings.resolvedLanguage == .zh ? "合并日志流" : "Merged log stream")
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .help(settings.t("new_process"))
                    Button { settings.showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .help(settings.t("settings"))
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddProjectSheet()
                .environment(manager)
                .environment(settings)
        }
    }
}
